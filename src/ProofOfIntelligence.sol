// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProofOfIntelligence
 * @notice On-chain verification that an address is controlled by an AI agent
 * @dev Challenges require reasoning + speed + crypto - things agents excel at
 */

interface IAgentRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

contract ProofOfIntelligence {
    
    // ============ State ============
    
    IAgentRegistry public immutable agentRegistry;
    
    struct Challenge {
        uint8 challengeType;      // Type of challenge (1-4)
        bytes32 seed;             // Random seed for challenge generation
        uint256 deadline;         // Block number deadline
        uint256 issuedBlock;      // Block when challenge was issued
        uint256 issuedTimestamp;  // Timestamp when challenge was issued
        bool completed;           // Whether solved
    }
    
    struct PoICredential {
        uint256 issuedAt;         // Timestamp of issuance
        uint8 challengeType;      // Which challenge type was passed
        uint256 blockSolved;      // Block when solved
        bool valid;               // Can be revoked
    }
    
    // Active challenges per address
    mapping(address => Challenge) public challenges;
    
    // PoI credentials per address
    mapping(address => PoICredential) public credentials;
    
    // Cooldown tracking (one attempt per hour)
    mapping(address => uint256) public lastAttempt;
    
    // Stats
    uint256 public totalChallengesIssued;
    uint256 public totalPassed;
    uint256 public totalFailed;
    
    // Config
    uint256 public constant CHALLENGE_WINDOW = 50;     // blocks to solve (~10 min on Base)
    uint256 public constant COOLDOWN_PERIOD = 1 hours;
    
    // ============ Events ============
    
    event ChallengeIssued(address indexed agent, uint8 challengeType, bytes32 seed, uint256 deadline);
    event ChallengePassed(address indexed agent, uint8 challengeType, uint256 blockNumber);
    event ChallengeFailed(address indexed agent, string reason);
    event CredentialRevoked(address indexed agent, string reason);
    
    // ============ Errors ============
    
    error NotRegisteredAgent();
    error ChallengeAlreadyActive();
    error NoChallengeActive();
    error ChallengExpired();
    error IncorrectAnswer();
    error CooldownNotElapsed();
    error AlreadyHasCredential();
    
    // ============ Constructor ============
    
    constructor(address _agentRegistry) {
        agentRegistry = IAgentRegistry(_agentRegistry);
    }
    
    // ============ Challenge Generation ============
    
    /**
     * @notice Request a new challenge
     * @dev Must be a registered ERC-8004 agent and pass cooldown
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
        seed = keccak256(abi.encodePacked(
            block.prevrandao,
            block.timestamp,
            msg.sender,
            totalChallengesIssued
        ));
        
        // Rotate through challenge types (1-4)
        challengeType = uint8((uint256(seed) % 4) + 1);
        deadline = block.number + CHALLENGE_WINDOW;
        
        // Store challenge
        challenges[msg.sender] = Challenge({
            challengeType: challengeType,
            seed: seed,
            deadline: deadline,
            issuedBlock: block.number,
            issuedTimestamp: block.timestamp,
            completed: false
        });
        
        lastAttempt[msg.sender] = block.timestamp;
        totalChallengesIssued++;
        
        emit ChallengeIssued(msg.sender, challengeType, seed, deadline);
        
        return (seed, challengeType, deadline);
    }
    
    /**
     * @notice Submit answer to active challenge
     * @param answer The computed answer based on challenge type
     */
    function submitAnswer(bytes32 answer) external {
        Challenge storage challenge = challenges[msg.sender];
        
        // Must have active challenge
        if (challenge.deadline == 0) revert NoChallengeActive();
        if (challenge.completed) revert NoChallengeActive();
        
        // Must be within deadline
        if (block.number > challenge.deadline) {
            challenge.completed = true;
            totalFailed++;
            emit ChallengeFailed(msg.sender, "Deadline expired");
            revert ChallengExpired();
        }
        
        // Compute expected answer based on challenge type using stored block data
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
            emit ChallengeFailed(msg.sender, "Incorrect answer");
            revert IncorrectAnswer();
        }
        
        // Success! Issue credential
        challenge.completed = true;
        totalPassed++;
        
        credentials[msg.sender] = PoICredential({
            issuedAt: block.timestamp,
            challengeType: challenge.challengeType,
            blockSolved: block.number,
            valid: true
        });
        
        emit ChallengePassed(msg.sender, challenge.challengeType, block.number);
    }
    
    /**
     * @notice Compute the expected answer for a challenge
     * @dev Uses stored challenge block data for deterministic answers
     */
    function computeExpectedAnswer(
        uint8 challengeType,
        bytes32 seed,
        address agent
    ) public view returns (bytes32) {
        // Get stored challenge data for block-dependent types
        Challenge storage challenge = challenges[agent];
        return _computeAnswer(challengeType, seed, agent, challenge.issuedBlock, challenge.issuedTimestamp);
    }
    
    /**
     * @notice Internal answer computation with explicit block data
     */
    function _computeAnswer(
        uint8 challengeType,
        bytes32 seed,
        address agent,
        uint256 blockNum,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        
        if (challengeType == 1) {
            // Type 1: Hash of seed + prime
            uint256 primeIndex = (uint256(seed) % 20) + 1;
            uint256 prime = getNthPrime(primeIndex);
            return keccak256(abi.encodePacked(seed, prime));
            
        } else if (challengeType == 2) {
            // Type 2: Conditional logic based on issued block state
            if (blockNum % 7 < 3) {
                return keccak256(abi.encodePacked(agent, seed));
            } else if (timestamp % 2 == 0) {
                return keccak256(abi.encodePacked(blockNum, seed));
            } else {
                return keccak256(abi.encodePacked("fallback", seed, agent));
            }
            
        } else if (challengeType == 3) {
            // Type 3: Mathematical sequence
            uint256 fibIndex = uint256(seed) % 20;
            uint256 fib = getFibonacci(fibIndex);
            return keccak256(abi.encodePacked(uint256(seed) ^ fib));
            
        } else {
            // Type 4: Multi-hash chain
            bytes32 h1 = keccak256(abi.encodePacked(seed, agent));
            bytes32 h2 = keccak256(abi.encodePacked(h1, blockNum));
            return keccak256(abi.encodePacked(h2, timestamp));
        }
    }
    
    // ============ Credential Queries ============
    
    /**
     * @notice Check if an address has a valid PoI credential
     */
    function hasValidPoI(address agent) external view returns (bool) {
        return credentials[agent].valid && credentials[agent].issuedAt > 0;
    }
    
    /**
     * @notice Check if address is both registered AND has PoI
     */
    function isVerifiedIntelligentAgent(address agent) external view returns (bool) {
        return agentRegistry.balanceOf(agent) > 0 && 
               credentials[agent].valid && 
               credentials[agent].issuedAt > 0;
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
    
    // ============ Helper Functions ============
    
    /**
     * @notice Get the nth prime number (1-indexed, up to 50)
     */
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
    
    /**
     * @notice Get the nth Fibonacci number (0-indexed, up to 30)
     */
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
     * @notice Revoke a credential (e.g., if fraud detected)
     * @dev In production, this would have access control
     */
    function revokeCredential(address agent, string calldata reason) external {
        // TODO: Add access control (owner, DAO, etc.)
        credentials[agent].valid = false;
        emit CredentialRevoked(agent, reason);
    }
}
