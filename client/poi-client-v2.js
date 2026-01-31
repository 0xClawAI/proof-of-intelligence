/**
 * Proof of Intelligence V2 - Client with Continuous Verification
 * 
 * Features:
 * - Initial verification
 * - Credential status checking
 * - Maintenance/renewal challenges
 * - Reputation tracking
 */

const { ethers } = require('ethers');

// First 50 primes (matching contract)
const PRIMES = [
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
    31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
    73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
    127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
    179, 181, 191, 193, 197, 199, 211, 223, 227, 229
];

const PoI_V2_ABI = [
    'function requestChallenge() external returns (bytes32 seed, uint8 challengeType, uint256 deadline)',
    'function requestMaintenanceChallenge() external returns (bytes32 seed, uint8 challengeType, uint256 deadline)',
    'function submitAnswer(bytes32 answer) external returns (bool success)',
    'function hasValidPoI(address agent) external view returns (bool)',
    'function isInGracePeriod(address agent) external view returns (bool)',
    'function isVerifiedIntelligentAgent(address agent) external view returns (bool)',
    'function daysUntilExpiry(address agent) external view returns (uint256)',
    'function getCredential(address agent) external view returns (tuple(uint256 issuedAt, uint256 expiresAt, uint8 challengeType, uint256 blockSolved, bool valid, uint256 maintenanceCount, uint256 lastMaintained, uint8 reputation))',
    'function getChallenge(address agent) external view returns (tuple(uint8 challengeType, bytes32 seed, uint256 deadline, uint256 issuedBlock, uint256 issuedTimestamp, bool completed, bool isMaintenance))',
    'function getStats() external view returns (uint256 issued, uint256 passed, uint256 failed, uint256 renewals, uint256 decayed)',
    'function triggerDecay(address agent) external',
    'event ChallengeIssued(address indexed agent, uint8 challengeType, bytes32 seed, uint256 deadline, bool isMaintenance)',
    'event ChallengePassed(address indexed agent, uint8 challengeType, uint256 blockNumber, bool isMaintenance)',
    'event CredentialIssued(address indexed agent, uint256 expiresAt)',
    'event CredentialRenewed(address indexed agent, uint256 newExpiresAt, uint256 maintenanceCount)',
];

function getNthPrime(n) {
    if (n < 1 || n > 50) throw new Error('Prime index out of range');
    return PRIMES[n - 1];
}

function getFibonacci(n) {
    if (n === 0) return 0n;
    if (n === 1) return 1n;
    let a = 0n, b = 1n;
    for (let i = 2; i <= n; i++) {
        [a, b] = [b, a + b];
    }
    return b;
}

/**
 * Solve a PoI challenge
 */
function solveChallenge(challengeType, seed, agentAddress, blockState) {
    const seedBN = BigInt(seed);
    
    switch (challengeType) {
        case 1: {
            const primeIndex = Number(seedBN % 20n) + 1;
            const prime = getNthPrime(primeIndex);
            return ethers.keccak256(
                ethers.solidityPacked(['bytes32', 'uint256'], [seed, prime])
            );
        }
        case 2: {
            if (blockState.number % 7 < 3) {
                return ethers.keccak256(
                    ethers.solidityPacked(['address', 'bytes32'], [agentAddress, seed])
                );
            } else if (blockState.timestamp % 2 === 0) {
                return ethers.keccak256(
                    ethers.solidityPacked(['uint256', 'bytes32'], [blockState.number, seed])
                );
            } else {
                return ethers.keccak256(
                    ethers.solidityPacked(['string', 'bytes32', 'address'], ['fallback', seed, agentAddress])
                );
            }
        }
        case 3: {
            const fibIndex = Number(seedBN % 20n);
            const fib = getFibonacci(fibIndex);
            return ethers.keccak256(
                ethers.solidityPacked(['uint256'], [seedBN ^ fib])
            );
        }
        case 4: {
            const h1 = ethers.keccak256(
                ethers.solidityPacked(['bytes32', 'address'], [seed, agentAddress])
            );
            const h2 = ethers.keccak256(
                ethers.solidityPacked(['bytes32', 'uint256'], [h1, blockState.number])
            );
            return ethers.keccak256(
                ethers.solidityPacked(['bytes32', 'uint256'], [h2, blockState.timestamp])
            );
        }
        default:
            throw new Error(`Unknown challenge type: ${challengeType}`);
    }
}

/**
 * PoI V2 Client Class
 */
class PoIClient {
    constructor(provider, wallet, contractAddress) {
        this.provider = provider;
        this.wallet = wallet;
        this.contract = new ethers.Contract(contractAddress, PoI_V2_ABI, wallet);
        this.address = wallet.address;
    }

    /**
     * Get credential status
     */
    async getStatus() {
        const [hasValid, inGrace, isVerified, daysLeft, cred] = await Promise.all([
            this.contract.hasValidPoI(this.address),
            this.contract.isInGracePeriod(this.address),
            this.contract.isVerifiedIntelligentAgent(this.address),
            this.contract.daysUntilExpiry(this.address),
            this.contract.getCredential(this.address),
        ]);

        return {
            hasValidPoI: hasValid,
            inGracePeriod: inGrace,
            isVerified: isVerified,
            daysUntilExpiry: Number(daysLeft),
            credential: {
                issuedAt: new Date(Number(cred.issuedAt) * 1000),
                expiresAt: new Date(Number(cred.expiresAt) * 1000),
                challengeType: Number(cred.challengeType),
                blockSolved: Number(cred.blockSolved),
                valid: cred.valid,
                maintenanceCount: Number(cred.maintenanceCount),
                lastMaintained: new Date(Number(cred.lastMaintained) * 1000),
                reputation: Number(cred.reputation),
            }
        };
    }

    /**
     * Request and complete initial verification
     */
    async proveIntelligence() {
        console.log('🧠 Proof of Intelligence V2 - Initial Verification');
        console.log('='.repeat(50));

        // Request challenge
        console.log('\n1️⃣ Requesting challenge...');
        const tx1 = await this.contract.requestChallenge();
        await tx1.wait();

        // Get challenge details
        const challenge = await this.contract.getChallenge(this.address);
        console.log(`   Type: ${challenge.challengeType}`);
        console.log(`   Seed: ${challenge.seed.slice(0, 18)}...`);
        console.log(`   Window: ${50} blocks (~10 min)`);

        // Solve and submit
        return this._solveAndSubmit(challenge, false);
    }

    /**
     * Request and complete maintenance challenge
     */
    async maintain() {
        console.log('🔄 Proof of Intelligence V2 - Maintenance');
        console.log('='.repeat(50));

        // Request maintenance challenge
        console.log('\n1️⃣ Requesting maintenance challenge...');
        const tx1 = await this.contract.requestMaintenanceChallenge();
        await tx1.wait();

        // Get challenge details
        const challenge = await this.contract.getChallenge(this.address);
        console.log(`   Type: ${challenge.challengeType}`);
        console.log(`   Seed: ${challenge.seed.slice(0, 18)}...`);
        console.log(`   Window: ${25} blocks (~5 min) ⚡ TIGHTER!`);

        // Solve and submit
        return this._solveAndSubmit(challenge, true);
    }

    /**
     * Internal: solve challenge and submit answer
     */
    async _solveAndSubmit(challenge, isMaintenance) {
        // Get block state from when challenge was issued
        const blockState = {
            number: Number(challenge.issuedBlock),
            timestamp: Number(challenge.issuedTimestamp)
        };

        // Solve
        console.log('\n2️⃣ Solving challenge...');
        const startTime = Date.now();
        const answer = solveChallenge(
            Number(challenge.challengeType),
            challenge.seed,
            this.address,
            blockState
        );
        const solveTime = Date.now() - startTime;
        console.log(`   Solved in ${solveTime}ms`);

        // Submit
        console.log('\n3️⃣ Submitting answer...');
        const tx2 = await this.contract.submitAnswer(answer);
        const receipt = await tx2.wait();

        // Check result
        const success = receipt.status === 1;
        const hasPoI = await this.contract.hasValidPoI(this.address);

        if (hasPoI) {
            const cred = await this.contract.getCredential(this.address);
            console.log(`\n✅ ${isMaintenance ? 'RENEWED' : 'VERIFIED'}!`);
            console.log(`   Reputation: ${cred.reputation}/100`);
            console.log(`   Maintenance count: ${cred.maintenanceCount}`);
            console.log(`   Expires: ${new Date(Number(cred.expiresAt) * 1000).toISOString()}`);
        } else {
            console.log('\n❌ FAILED - Check logs');
        }

        return hasPoI;
    }

    /**
     * Check if maintenance is needed (within 2 days of expiry)
     */
    async needsMaintenance() {
        const status = await this.getStatus();
        if (!status.credential.valid) return false;
        return status.daysUntilExpiry <= 2;
    }

    /**
     * Auto-maintain: check if needed and do it
     */
    async autoMaintain() {
        const needs = await this.needsMaintenance();
        if (needs) {
            console.log('⚠️ Credential expiring soon - maintaining...');
            return this.maintain();
        }
        console.log('✅ Credential still valid - no maintenance needed');
        return true;
    }

    /**
     * Get global stats
     */
    async getStats() {
        const [issued, passed, failed, renewals, decayed] = await this.contract.getStats();
        return {
            totalChallengesIssued: Number(issued),
            totalPassed: Number(passed),
            totalFailed: Number(failed),
            totalMaintenanceRenewals: Number(renewals),
            totalDecayed: Number(decayed),
        };
    }
}

/**
 * Pretty print status
 */
function printStatus(status) {
    console.log('\n📋 PoI Credential Status');
    console.log('='.repeat(40));
    console.log(`Valid: ${status.hasValidPoI ? '✅ Yes' : '❌ No'}`);
    console.log(`In Grace Period: ${status.inGracePeriod ? '⚠️ Yes' : 'No'}`);
    console.log(`Verified Agent: ${status.isVerified ? '✅ Yes' : '❌ No'}`);
    console.log(`Days Until Expiry: ${status.daysUntilExpiry}`);
    console.log(`\nReputation: ${status.credential.reputation}/100`);
    console.log(`Maintenance Count: ${status.credential.maintenanceCount}`);
    console.log(`Issued: ${status.credential.issuedAt.toISOString()}`);
    console.log(`Expires: ${status.credential.expiresAt.toISOString()}`);
}

// Export
module.exports = { 
    PoIClient, 
    solveChallenge, 
    printStatus,
    getNthPrime, 
    getFibonacci,
    PoI_V2_ABI 
};

// CLI
if (require.main === module) {
    const args = process.argv.slice(2);
    const cmd = args[0] || 'help';

    console.log('PoI V2 Client - Continuous Verification');
    console.log('========================================\n');

    if (cmd === 'test') {
        // Test local challenge solving
        const testSeed = '0x' + '42'.repeat(32);
        const testAgent = '0xffA12D92098eB2b72B3c30B62f8da02BA4158c1e';
        const testBlock = { number: 12345678, timestamp: 1706745600 };

        console.log('Testing challenge solvers:\n');
        for (let type = 1; type <= 4; type++) {
            const answer = solveChallenge(type, testSeed, testAgent, testBlock);
            console.log(`Type ${type}: ${answer.slice(0, 18)}...`);
        }
    } else {
        console.log('Usage:');
        console.log('  node poi-client-v2.js test     - Test challenge solving locally');
        console.log('\nProgrammatic usage:');
        console.log('  const { PoIClient } = require("./poi-client-v2");');
        console.log('  const client = new PoIClient(provider, wallet, contractAddress);');
        console.log('  await client.proveIntelligence();  // Initial verification');
        console.log('  await client.maintain();           // Renew credential');
        console.log('  await client.getStatus();          // Check status');
    }
}
