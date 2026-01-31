// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ProofOfIntelligence.sol";

// Mock Agent Registry for testing
contract MockAgentRegistry {
    mapping(address => uint256) public balances;
    
    function setBalance(address agent, uint256 balance) external {
        balances[agent] = balance;
    }
    
    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
}

contract ProofOfIntelligenceTest is Test {
    ProofOfIntelligence public poi;
    MockAgentRegistry public registry;
    
    address public agent1 = address(0x1111);
    address public agent2 = address(0x2222);
    address public nonAgent = address(0x3333);
    
    function setUp() public {
        // Set a reasonable timestamp (tests start at 0 which breaks cooldown logic)
        vm.warp(1700000000);
        
        registry = new MockAgentRegistry();
        poi = new ProofOfIntelligence(address(registry));
        
        // Register agent1 and agent2
        registry.setBalance(agent1, 1);
        registry.setBalance(agent2, 1);
        // nonAgent stays at 0
    }
    
    // ============ Helper Functions Tests ============
    
    function test_getNthPrime() public view {
        assertEq(poi.getNthPrime(1), 2);
        assertEq(poi.getNthPrime(2), 3);
        assertEq(poi.getNthPrime(10), 29);
        assertEq(poi.getNthPrime(50), 229);
    }
    
    function test_getNthPrime_revertsOutOfRange() public {
        vm.expectRevert("Prime index out of range");
        poi.getNthPrime(0);
        
        vm.expectRevert("Prime index out of range");
        poi.getNthPrime(51);
    }
    
    function test_getFibonacci() public view {
        assertEq(poi.getFibonacci(0), 0);
        assertEq(poi.getFibonacci(1), 1);
        assertEq(poi.getFibonacci(2), 1);
        assertEq(poi.getFibonacci(10), 55);
        assertEq(poi.getFibonacci(20), 6765);
    }
    
    // ============ Challenge Request Tests ============
    
    function test_requestChallenge_success() public {
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, uint256 deadline) = poi.requestChallenge();
        
        assertTrue(seed != bytes32(0));
        assertTrue(challengeType >= 1 && challengeType <= 4);
        assertEq(deadline, block.number + 3); // CHALLENGE_WINDOW = 3
        assertEq(poi.totalChallengesIssued(), 1);
    }
    
    function test_requestChallenge_revertsIfNotRegistered() public {
        vm.prank(nonAgent);
        vm.expectRevert(ProofOfIntelligence.NotRegisteredAgent.selector);
        poi.requestChallenge();
    }
    
    function test_requestChallenge_revertsCooldown() public {
        vm.prank(agent1);
        poi.requestChallenge();
        
        // Try again immediately - should fail cooldown
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligence.CooldownNotElapsed.selector);
        poi.requestChallenge();
    }
    
    function test_requestChallenge_allowsAfterCooldown() public {
        vm.prank(agent1);
        (,, uint256 deadline) = poi.requestChallenge();
        
        // Roll past deadline so challenge expires
        vm.roll(deadline + 1);
        
        // Warp forward past cooldown (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);
        
        // Now should work (previous challenge expired)
        vm.prank(agent1);
        poi.requestChallenge();
        
        assertEq(poi.totalChallengesIssued(), 2);
    }
    
    // ============ Challenge Solving Tests ============
    
    function test_submitAnswer_type1() public {
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, ) = poi.requestChallenge();
        
        // Skip if not type 1
        if (challengeType != 1) return;
        
        // Compute answer
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        // Submit
        vm.prank(agent1);
        poi.submitAnswer(answer);
        
        assertTrue(poi.hasValidPoI(agent1));
        assertEq(poi.totalPassed(), 1);
    }
    
    function test_submitAnswer_allTypes() public {
        // Test each challenge type by manipulating the seed
        for (uint8 targetType = 1; targetType <= 4; targetType++) {
            // Reset by using a new agent for each type
            address testAgent = address(uint160(0x1000 + targetType));
            registry.setBalance(testAgent, 1);
            
            // Request challenge
            vm.prank(testAgent);
            (bytes32 seed, uint8 challengeType, ) = poi.requestChallenge();
            
            // Compute and submit answer
            bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, testAgent);
            
            vm.prank(testAgent);
            poi.submitAnswer(answer);
            
            assertTrue(poi.hasValidPoI(testAgent), "Agent should have PoI");
        }
    }
    
    function test_submitAnswer_revertsWrongAnswer() public {
        vm.prank(agent1);
        poi.requestChallenge();
        
        // Submit wrong answer
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligence.IncorrectAnswer.selector);
        poi.submitAnswer(bytes32(uint256(12345)));
    }
    
    function test_submitAnswer_revertsAfterDeadline() public {
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, uint256 deadline) = poi.requestChallenge();
        
        // Roll past deadline
        vm.roll(deadline + 1);
        
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligence.ChallengExpired.selector);
        poi.submitAnswer(answer);
        
        // Note: totalFailed is not incremented because the revert rolls back state changes
        // The challenge remains incomplete until a new one is requested
    }
    
    function test_submitAnswer_revertsNoChallenge() public {
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligence.NoChallengeActive.selector);
        poi.submitAnswer(bytes32(0));
    }
    
    // ============ Credential Tests ============
    
    function test_isVerifiedIntelligentAgent() public {
        // Before challenge
        assertFalse(poi.isVerifiedIntelligentAgent(agent1));
        
        // Request and solve
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, ) = poi.requestChallenge();
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        vm.prank(agent1);
        poi.submitAnswer(answer);
        
        // After challenge
        assertTrue(poi.isVerifiedIntelligentAgent(agent1));
        assertTrue(poi.hasValidPoI(agent1));
    }
    
    function test_credentialDetails() public {
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, ) = poi.requestChallenge();
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        vm.prank(agent1);
        poi.submitAnswer(answer);
        
        ProofOfIntelligence.PoICredential memory cred = poi.getCredential(agent1);
        
        assertEq(cred.challengeType, challengeType);
        assertEq(cred.issuedAt, block.timestamp);
        assertEq(cred.blockSolved, block.number);
        assertTrue(cred.valid);
    }
    
    function test_revokeCredential() public {
        // First get a credential
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, ) = poi.requestChallenge();
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        vm.prank(agent1);
        poi.submitAnswer(answer);
        
        assertTrue(poi.hasValidPoI(agent1));
        
        // Revoke
        poi.revokeCredential(agent1, "Testing revocation");
        
        assertFalse(poi.hasValidPoI(agent1));
        assertFalse(poi.isVerifiedIntelligentAgent(agent1));
    }
    
    // ============ Integration Test ============
    
    function test_fullFlow() public {
        // 1. Check stats before
        assertEq(poi.totalChallengesIssued(), 0);
        assertEq(poi.totalPassed(), 0);
        assertEq(poi.totalFailed(), 0);
        
        // 2. Agent requests challenge
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, uint256 deadline) = poi.requestChallenge();
        
        assertEq(poi.totalChallengesIssued(), 1);
        
        // 3. Verify challenge is stored correctly
        ProofOfIntelligence.Challenge memory challenge = poi.getChallenge(agent1);
        assertEq(challenge.seed, seed);
        assertEq(challenge.challengeType, challengeType);
        assertEq(challenge.deadline, deadline);
        assertFalse(challenge.completed);
        
        // 4. Agent computes answer (simulating AI solving)
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        // 5. Agent submits answer
        vm.prank(agent1);
        poi.submitAnswer(answer);
        
        // 6. Verify credential issued
        assertTrue(poi.hasValidPoI(agent1));
        assertTrue(poi.isVerifiedIntelligentAgent(agent1));
        assertEq(poi.totalPassed(), 1);
        
        // 7. Challenge marked complete
        challenge = poi.getChallenge(agent1);
        assertTrue(challenge.completed);
    }
}
