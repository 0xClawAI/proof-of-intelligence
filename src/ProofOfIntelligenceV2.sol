// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProofOfIntelligenceV2
 * @notice Continuous verification that an address is controlled by an AI agent
 * @dev V2 adds: credential expiry, maintenance challenges, speed gates, decay
 * 
 * Key improvements over V1:
 * - Credentials expire after CREDENTIAL_VALIDITY_PERIOD (7 days)
 * - Agents must call maintainCredential() before expiry to renew
 * - Maintenance challenges have tighter speed requirements (25 blocks vs 50)
 * - Reputation score tracks successful maintenance streaks
 * - Decayed credentials require fresh initial verification
 */

interface IAgentRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

contract ProofOfIntelligenceV2 {
    
    // ============ Constants ============
    
    uint256 public constant INITIAL_CHALLENGE_WINDOW = 50;   // ~10 min on Base
    uint256 public constant MAINTENANCE_CHALLENGE_WINDOW = 25; // ~5 min - faster!
    uint256 public constant COOLDOWN_PERIOD = 1 hours;
    uint256 public constant CREDENTIAL_VALIDITY_PERIOD = 7 days;
    uint256 public constant GRACE_PERIOD = 1 days;           // Extra time before full decay
    
    // ============ State ============
    
    IAgentRegistry public immutable agentRegistry;
    
    struct Challenge {
        uint8 challengeType;
        bytes32 seed;
        uint256 deadline;
        uint256 issuedBlock;
        uint256 issuedTimestamp;
        bool completed;
        bool isMaintenance;      // NEW: maintenance challenges have tighter windows
    }
    
    struct PoICredential {
        uint256 issuedAt;
        uint256 expiresAt;        // NEW: credential expiry
        uint8 challengeType;
        uint256 blockSolved;
        bool valid;
        uint256 maintenanceCount; // NEW: track successful renewals
        uint256 lastMaintained;   // NEW: when last renewed
        uint8 reputation;         // NEW: 0-100 reputation score
    }
    
    // Active challenges per address
    mapping(address => Challenge) public challenges;
    
    // PoI credentials per address
    mapping(address => PoICredential) public credentials;
    
    // Cooldown tracking
    mapping(address => uint256) public lastAttempt;
    
    // Stats
    uint256 public totalChallengesIssued;
    uint256 public totalPassed;
    uint256 public totalFailed;
    uint256 public totalMaintenanceRenewals;
    uint256 public totalDecayed;
    
    // ============ Events ============
    
    event ChallengeIssued(address indexed agent, uint8 challengeType, bytes32 seed, uint256 deadline, bool isMaintenance);
    event ChallengePassed(address indexed agent, uint8 challengeType, uint256 blockNumber, bool isMaintenance);
    event ChallengeFailed(address indexed agent, string reason);
    event CredentialIssued(address indexed agent, uint256 expiresAt);
    event CredentialRenewed(address indexed agent, uint256 newExpiresAt, uint256 maintenanceCount);
    event CredentialDecayed(address indexed agent, string reason);
    event CredentialRevoked(address indexed agent, string reason);
    event ReputationUpdated(address indexed agent, uint8 newReputation);
    
    // ============ Errors ============
    
    error NotRegisteredAgent();
    error ChallengeAlreadyActive();
    error NoChallengeActive();
    error ChallengeExpired();
    error IncorrectAnswer();
    error CooldownNotElapsed();
    error CredentialNotExpiringSoon();
    error CredentialAlreadyDecayed();
    error NoCredentialToMaintain();
    
    // ============ Constructor ============
    
    constructor(address _agentRegistry) {
        agentRegistry = IAgentRegistry(_agentRegistry);
    }
    
    // ============ Initial Verification ============
    
    /**
     * @notice Request an initial challenge (for agents without credential)
     * @dev Must be a registered ERC-8004 agent
     */
    function requestChallenge() external returns (bytes32 seed, uint8 challengeType, uint256 deadline) {
        // Must be registered agent
        if (agentRegistry.balanceOf(msg.sender) == 0) revert NotRegisteredAgent();
        
        // Check cooldown
        if (block.timestamp < lastAttempt[msg.sender] + COOLDOWN_PERIOD) {
            revert CooldownNotElapsed();
        }
        
        // Can't have active challenge
        Challenge storage existing = challenges[msg.sender];
        if (existing.deadline > block.number && !existing.completed) {
            revert ChallengeAlreadyActive();
        }
        
        // Generate challenge
        seed = _generateSeed();
        challengeType = uint8((uint256(seed) % 4) + 1);
        deadline = block.number + INITIAL_CHALLENGE_WINDOW;
        
        // Store challenge
        challenges[msg.sender] = Challenge({
            challengeType: challengeType,
            seed: seed,
            deadline: deadline,
            issuedBlock: block.number,
            issuedTimestamp: block.timestamp,
            completed: false,
            isMaintenance: false
        });
        
        lastAttempt[msg.sender] = block.timestamp;
        totalChallengesIssued++;
        
        emit ChallengeIssued(msg.sender, challengeType, seed, deadline, false);
        
        return (seed, challengeType, deadline);
    }
    
    // ============ Maintenance (Continuous Verification) ============
    
    /**
     * @notice Request a maintenance challenge to renew expiring credential
     * @dev Can only be called when credential expires within 2 days
     */
    function requestMaintenanceChallenge() external returns (bytes32 seed, uint8 challengeType, uint256 deadline) {
        // Must be registered agent
        if (agentRegistry.balanceOf(msg.sender) == 0) revert NotRegisteredAgent();
        
        PoICredential storage cred = credentials[msg.sender];
        
        // Must have existing valid credential
        if (!cred.valid || cred.issuedAt == 0) revert NoCredentialToMaintain();
        
        // Check if fully decayed (past grace period)
        if (block.timestamp > cred.expiresAt + GRACE_PERIOD) {
            _decayCredential(msg.sender, "Expired past grace period");
            revert CredentialAlreadyDecayed();
        }
        
        // Can only maintain within last 2 days before expiry
        if (block.timestamp < cred.expiresAt - 2 days) {
            revert CredentialNotExpiringSoon();
        }
        
        // Check cooldown (30 min for maintenance)
        if (block.timestamp < lastAttempt[msg.sender] + 30 minutes) {
            revert CooldownNotElapsed();
        }
        
        // Can't have active challenge
        Challenge storage existing = challenges[msg.sender];
        if (existing.deadline > block.number && !existing.completed) {
            revert ChallengeAlreadyActive();
        }
        
        // Generate maintenance challenge (tighter deadline)
        seed = _generateSeed();
        challengeType = uint8((uint256(seed) % 4) + 1);
        deadline = block.number + MAINTENANCE_CHALLENGE_WINDOW; // Faster!
        
        // Store challenge
        challenges[msg.sender] = Challenge({
            challengeType: challengeType,
            seed: seed,
            deadline: deadline,
            issuedBlock: block.number,
            issuedTimestamp: block.timestamp,
            completed: false,
            isMaintenance: true
        });
        
        lastAttempt[msg.sender] = block.timestamp;
        totalChallengesIssued++;
        
        emit ChallengeIssued(msg.sender, challengeType, seed, deadline, true);
        
        return (seed, challengeType, deadline);
    }
    
    /**
     * @notice Submit answer to active challenge
     * @param answer The computed answer based on challenge type
     * @return success Whether the answer was correct
     */
    function submitAnswer(bytes32 answer) external returns (bool success) {
        Challenge storage challenge = challenges[msg.sender];
        
        // Must have active challenge
        if (challenge.deadline == 0) revert NoChallengeActive();
        if (challenge.completed) revert NoChallengeActive();
        
        // Must be within deadline
        if (block.number > challenge.deadline) {
            challenge.completed = true;
            totalFailed++;
            emit ChallengeFailed(msg.sender, "Deadline expired");
            return false; // Don't revert - allows counter to persist
        }
        
        // Compute expected answer
        bytes32 expectedAnswer = _computeAnswer(
            challenge.challengeType,
            challenge.seed,
            msg.sender,
            challenge.issuedBlock,
            challenge.issuedTimestamp
        );
        
        // Verify answer
        if (answer != expectedAnswer) {
            challenge.completed = true;
            totalFailed++;
            
            // Failed maintenance reduces reputation
            if (challenge.isMaintenance) {
                _reduceReputation(msg.sender, 10);
            }
            
            emit ChallengeFailed(msg.sender, "Incorrect answer");
            return false; // Don't revert - allows counter to persist
        }
        
        // Success!
        challenge.completed = true;
        totalPassed++;
        
        if (challenge.isMaintenance) {
            // Renew credential
            _renewCredential(msg.sender, challenge.challengeType);
        } else {
            // Issue new credential
            _issueCredential(msg.sender, challenge.challengeType);
        }
        
        emit ChallengePassed(msg.sender, challenge.challengeType, block.number, challenge.isMaintenance);
        return true;
    }
    
    // ============ Credential Management (Internal) ============
    
    function _issueCredential(address agent, uint8 challengeType) internal {
        uint256 expiresAt = block.timestamp + CREDENTIAL_VALIDITY_PERIOD;
        
        credentials[agent] = PoICredential({
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            challengeType: challengeType,
            blockSolved: block.number,
            valid: true,
            maintenanceCount: 0,
            lastMaintained: block.timestamp,
            reputation: 50 // Start at 50
        });
        
        emit CredentialIssued(agent, expiresAt);
    }
    
    function _renewCredential(address agent, uint8 challengeType) internal {
        PoICredential storage cred = credentials[agent];
        
        uint256 newExpiresAt = block.timestamp + CREDENTIAL_VALIDITY_PERIOD;
        cred.expiresAt = newExpiresAt;
        cred.maintenanceCount++;
        cred.lastMaintained = block.timestamp;
        
        // Boost reputation for successful maintenance (max 100)
        _increaseReputation(agent, 5);
        
        totalMaintenanceRenewals++;
        
        emit CredentialRenewed(agent, newExpiresAt, cred.maintenanceCount);
    }
    
    function _decayCredential(address agent, string memory reason) internal {
        credentials[agent].valid = false;
        credentials[agent].reputation = 0;
        totalDecayed++;
        
        emit CredentialDecayed(agent, reason);
    }
    
    function _increaseReputation(address agent, uint8 amount) internal {
        PoICredential storage cred = credentials[agent];
        uint8 newRep = cred.reputation + amount;
        cred.reputation = newRep > 100 ? 100 : newRep;
        emit ReputationUpdated(agent, cred.reputation);
    }
    
    function _reduceReputation(address agent, uint8 amount) internal {
        PoICredential storage cred = credentials[agent];
        if (cred.reputation <= amount) {
            cred.reputation = 0;
        } else {
            cred.reputation -= amount;
        }
        emit ReputationUpdated(agent, cred.reputation);
    }
    
    // ============ Credential Queries ============
    
    /**
     * @notice Check if an address has a valid (non-expired) PoI credential
     */
    function hasValidPoI(address agent) external view returns (bool) {
        PoICredential storage cred = credentials[agent];
        return cred.valid && 
               cred.issuedAt > 0 && 
               block.timestamp <= cred.expiresAt;
    }
    
    /**
     * @notice Check if credential is in grace period (expired but not decayed)
     */
    function isInGracePeriod(address agent) external view returns (bool) {
        PoICredential storage cred = credentials[agent];
        return cred.valid && 
               block.timestamp > cred.expiresAt &&
               block.timestamp <= cred.expiresAt + GRACE_PERIOD;
    }
    
    /**
     * @notice Check if address is both registered AND has valid PoI
     */
    function isVerifiedIntelligentAgent(address agent) external view returns (bool) {
        PoICredential storage cred = credentials[agent];
        return agentRegistry.balanceOf(agent) > 0 && 
               cred.valid && 
               cred.issuedAt > 0 &&
               block.timestamp <= cred.expiresAt;
    }
    
    /**
     * @notice Get days until credential expires (0 if expired)
     */
    function daysUntilExpiry(address agent) external view returns (uint256) {
        PoICredential storage cred = credentials[agent];
        if (!cred.valid || block.timestamp >= cred.expiresAt) {
            return 0;
        }
        return (cred.expiresAt - block.timestamp) / 1 days;
    }
    
    /**
     * @notice Get full credential details
     */
    function getCredential(address agent) external view returns (PoICredential memory) {
        return credentials[agent];
    }
    
    /**
     * @notice Get active challenge details
     */
    function getChallenge(address agent) external view returns (Challenge memory) {
        return challenges[agent];
    }
    
    /**
     * @notice Get global stats
     */
    function getStats() external view returns (
        uint256 issued,
        uint256 passed,
        uint256 failed,
        uint256 renewals,
        uint256 decayed
    ) {
        return (totalChallengesIssued, totalPassed, totalFailed, totalMaintenanceRenewals, totalDecayed);
    }
    
    // ============ Helper Functions ============
    
    function _generateSeed() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            totalChallengesIssued
        ));
    }
    
    function _computeAnswer(
        uint8 challengeType,
        bytes32 seed,
        address agent,
        uint256 blockNum,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        
        if (challengeType == 1) {
            uint256 primeIndex = (uint256(seed) % 20) + 1;
            uint256 prime = getNthPrime(primeIndex);
            return keccak256(abi.encodePacked(seed, prime));
            
        } else if (challengeType == 2) {
            if (blockNum % 7 < 3) {
                return keccak256(abi.encodePacked(agent, seed));
            } else if (timestamp % 2 == 0) {
                return keccak256(abi.encodePacked(blockNum, seed));
            } else {
                return keccak256(abi.encodePacked("fallback", seed, agent));
            }
            
        } else if (challengeType == 3) {
            uint256 fibIndex = uint256(seed) % 20;
            uint256 fib = getFibonacci(fibIndex);
            return keccak256(abi.encodePacked(uint256(seed) ^ fib));
            
        } else {
            bytes32 h1 = keccak256(abi.encodePacked(seed, agent));
            bytes32 h2 = keccak256(abi.encodePacked(h1, blockNum));
            return keccak256(abi.encodePacked(h2, timestamp));
        }
    }
    
    /**
     * @notice Compute expected answer for external verification
     */
    function computeExpectedAnswer(
        uint8 challengeType,
        bytes32 seed,
        address agent
    ) public view returns (bytes32) {
        Challenge storage challenge = challenges[agent];
        return _computeAnswer(challengeType, seed, agent, challenge.issuedBlock, challenge.issuedTimestamp);
    }
    
    function getNthPrime(uint256 n) public pure returns (uint256) {
        uint256[50] memory primes = [
            uint256(2), 3, 5, 7, 11, 13, 17, 19, 23, 29,
            31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
            73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
            127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
            179, 181, 191, 193, 197, 199, 211, 223, 227, 229
        ];
        require(n > 0 && n <= 50, "Prime index out of range");
        return primes[n - 1];
    }
    
    function getFibonacci(uint256 n) public pure returns (uint256) {
        if (n == 0) return 0;
        if (n == 1) return 1;
        
        uint256 a = 0;
        uint256 b = 1;
        for (uint256 i = 2; i <= n; i++) {
            uint256 temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Force decay an expired credential
     * @dev Anyone can call this to clean up expired credentials
     */
    function triggerDecay(address agent) external {
        PoICredential storage cred = credentials[agent];
        
        if (!cred.valid) return; // Already decayed
        
        // Can only decay if past grace period
        if (block.timestamp > cred.expiresAt + GRACE_PERIOD) {
            _decayCredential(agent, "Triggered decay - past grace period");
        }
    }
    
    /**
     * @notice Revoke a credential (admin only in production)
     */
    function revokeCredential(address agent, string calldata reason) external {
        // TODO: Add access control
        credentials[agent].valid = false;
        emit CredentialRevoked(agent, reason);
    }
}
