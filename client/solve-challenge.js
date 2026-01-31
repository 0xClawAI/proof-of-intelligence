/**
 * Proof of Intelligence - Challenge Solver
 * 
 * This script demonstrates how an AI agent would solve PoI challenges.
 * Humans would struggle to do this within the 3-block time window (~36 seconds).
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

function getNthPrime(n) {
    if (n < 1 || n > 50) throw new Error('Prime index out of range');
    return PRIMES[n - 1];
}

function getFibonacci(n) {
    if (n === 0) return 0n;
    if (n === 1) return 1n;
    
    let a = 0n;
    let b = 1n;
    for (let i = 2; i <= n; i++) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

/**
 * Solve a PoI challenge
 * @param {number} challengeType - Type of challenge (1-4)
 * @param {string} seed - Challenge seed (bytes32 hex)
 * @param {string} agentAddress - Solver's address
 * @param {object} blockState - Current block state { number, timestamp }
 * @returns {string} The answer (bytes32 hex)
 */
function solveChallenge(challengeType, seed, agentAddress, blockState) {
    const seedBN = BigInt(seed);
    
    switch (challengeType) {
        case 1: {
            // Type 1: Hash of seed + prime
            const primeIndex = Number(seedBN % 20n) + 1;
            const prime = getNthPrime(primeIndex);
            
            return ethers.keccak256(
                ethers.solidityPacked(['bytes32', 'uint256'], [seed, prime])
            );
        }
        
        case 2: {
            // Type 2: Conditional logic based on block state
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
            // Type 3: Fibonacci sequence
            const fibIndex = Number(seedBN % 20n);
            const fib = getFibonacci(fibIndex);
            const xorResult = seedBN ^ fib;
            
            return ethers.keccak256(
                ethers.solidityPacked(['uint256'], [xorResult])
            );
        }
        
        case 4: {
            // Type 4: Multi-hash chain
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
 * Full flow: Request challenge, solve it, submit answer
 */
async function proveIntelligence(provider, wallet, poiContractAddress) {
    const PoI_ABI = [
        'function requestChallenge() external returns (bytes32 seed, uint8 challengeType, uint256 deadline)',
        'function submitAnswer(bytes32 answer) external',
        'function hasValidPoI(address agent) external view returns (bool)',
        'function getChallenge(address agent) external view returns (tuple(uint8 challengeType, bytes32 seed, uint256 deadline, bool completed))',
    ];
    
    const poi = new ethers.Contract(poiContractAddress, PoI_ABI, wallet);
    
    console.log('🧠 Proof of Intelligence - Challenge Flow');
    console.log('=========================================\n');
    
    // Step 1: Request challenge
    console.log('1️⃣ Requesting challenge...');
    const tx1 = await poi.requestChallenge();
    const receipt = await tx1.wait();
    
    // Parse the ChallengeIssued event
    const challenge = await poi.getChallenge(wallet.address);
    console.log(`   Challenge Type: ${challenge.challengeType}`);
    console.log(`   Seed: ${challenge.seed}`);
    console.log(`   Deadline: Block ${challenge.deadline}`);
    
    // Step 2: Get current block state
    const block = await provider.getBlock('latest');
    const blockState = {
        number: Number(block.number),
        timestamp: Number(block.timestamp)
    };
    console.log(`\n2️⃣ Current block: ${blockState.number}, deadline: ${challenge.deadline}`);
    console.log(`   Time remaining: ~${(Number(challenge.deadline) - blockState.number) * 12} seconds`);
    
    // Step 3: Solve challenge (this is where AI speed matters!)
    console.log('\n3️⃣ Solving challenge...');
    const startTime = Date.now();
    
    const answer = solveChallenge(
        Number(challenge.challengeType),
        challenge.seed,
        wallet.address,
        blockState
    );
    
    const solveTime = Date.now() - startTime;
    console.log(`   Answer computed in ${solveTime}ms`);
    console.log(`   Answer: ${answer}`);
    
    // Step 4: Submit answer
    console.log('\n4️⃣ Submitting answer...');
    const tx2 = await poi.submitAnswer(answer);
    await tx2.wait();
    
    // Step 5: Verify credential
    const hasPoI = await poi.hasValidPoI(wallet.address);
    console.log(`\n✅ Proof of Intelligence ${hasPoI ? 'VERIFIED' : 'FAILED'}!`);
    
    return hasPoI;
}

// Export for use as module
module.exports = { solveChallenge, proveIntelligence, getNthPrime, getFibonacci };

// CLI usage
if (require.main === module) {
    // Example: solve a challenge locally
    const testSeed = '0x' + '42'.repeat(32);
    const testAgent = '0xffA12D92098eB2b72B3c30B62f8da02BA4158c1e';
    const testBlock = { number: 12345678, timestamp: 1706745600 };
    
    console.log('Testing challenge solvers:\n');
    
    for (let type = 1; type <= 4; type++) {
        const answer = solveChallenge(type, testSeed, testAgent, testBlock);
        console.log(`Type ${type}: ${answer}`);
    }
}
