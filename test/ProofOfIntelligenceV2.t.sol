// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ProofOfIntelligenceV2.sol";

/**
 * @title MockAgentRegistryV2
 * @notice Mock registry for testing
 */
contract MockAgentRegistryV2 {
    mapping(address => uint256) public balances;
    
    function setBalance(address agent, uint256 balance) external {
        balances[agent] = balance;
    }
    
    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
}

contract ProofOfIntelligenceV2Test is Test {
    ProofOfIntelligenceV2 public poi;
    MockAgentRegistryV2 public registry;
    
    address public agent1 = address(0x1111);
    address public agent2 = address(0x2222);
    address public nonAgent = address(0x9999);
    
    function setUp() public {
        // Start at a reasonable timestamp to avoid cooldown edge cases
        vm.warp(1000000);
        
        registry = new MockAgentRegistryV2();
        poi = new ProofOfIntelligenceV2(address(registry));
        
        // Register agents
        registry.setBalance(agent1, 1);
        registry.setBalance(agent2, 1);
        // nonAgent stays unregistered
    }
    
    // ============ Initial Verification Tests ============
    
    function testRequestChallenge() public {
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, uint256 deadline) = poi.requestChallenge();
        
        assertGt(uint256(seed), 0, "Seed should be non-zero");
        assertTrue(challengeType >= 1 && challengeType <= 4, "Challenge type should be 1-4");
        assertEq(deadline, block.number + 50, "Deadline should be block + 50");
    }
    
    function testRequestChallengeNotRegistered() public {
        vm.prank(nonAgent);
        vm.expectRevert(ProofOfIntelligenceV2.NotRegisteredAgent.selector);
        poi.requestChallenge();
    }
    
    function testSubmitCorrectAnswer() public {
        vm.startPrank(agent1);
        
        // Request challenge
        (bytes32 seed, uint8 challengeType,) = poi.requestChallenge();
        
        // Compute answer
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent1);
        
        // Submit answer
        poi.submitAnswer(answer);
        
        vm.stopPrank();
        
        // Verify credential was issued
        assertTrue(poi.hasValidPoI(agent1), "Should have valid PoI");
        
        ProofOfIntelligenceV2.PoICredential memory cred = poi.getCredential(agent1);
        assertEq(cred.reputation, 50, "Initial reputation should be 50");
        assertGt(cred.expiresAt, block.timestamp, "Should have future expiry");
    }
    
    function testSubmitWrongAnswer() public {
        vm.startPrank(agent1);
        
        poi.requestChallenge();
        
        // Submit wrong answer - returns false, doesn't revert
        bool success = poi.submitAnswer(bytes32(uint256(12345)));
        assertFalse(success, "Should return false for wrong answer");
        
        vm.stopPrank();
        
        // Should not have credential
        assertFalse(poi.hasValidPoI(agent1), "Should not have PoI after wrong answer");
    }
    
    // ============ Expiry Tests ============
    
    function testCredentialExpiry() public {
        // Get credential
        _completeInitialVerification(agent1);
        
        // Initially valid
        assertTrue(poi.hasValidPoI(agent1), "Should be valid initially");
        
        // Fast forward 7 days + 1 second
        vm.warp(block.timestamp + 7 days + 1);
        
        // Should be expired (but not decayed)
        assertFalse(poi.hasValidPoI(agent1), "Should be expired");
        assertTrue(poi.isInGracePeriod(agent1), "Should be in grace period");
    }
    
    function testDaysUntilExpiry() public {
        _completeInitialVerification(agent1);
        
        assertEq(poi.daysUntilExpiry(agent1), 7, "Should be 7 days initially");
        
        // Fast forward 2 days
        vm.warp(block.timestamp + 2 days);
        assertEq(poi.daysUntilExpiry(agent1), 5, "Should be 5 days after 2 days");
        
        // Fast forward past expiry
        vm.warp(block.timestamp + 6 days);
        assertEq(poi.daysUntilExpiry(agent1), 0, "Should be 0 when expired");
    }
    
    // ============ Maintenance Tests ============
    
    function testRequestMaintenanceTooEarly() public {
        _completeInitialVerification(agent1);
        
        // Try to maintain immediately (should fail - not within 2 days of expiry)
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligenceV2.CredentialNotExpiringSoon.selector);
        poi.requestMaintenanceChallenge();
    }
    
    function testRequestMaintenanceInWindow() public {
        _completeInitialVerification(agent1);
        
        // Fast forward to 2 days before expiry
        vm.warp(block.timestamp + 5 days + 1);
        
        vm.prank(agent1);
        (bytes32 seed, uint8 challengeType, uint256 deadline) = poi.requestMaintenanceChallenge();
        
        assertGt(uint256(seed), 0, "Seed should be non-zero");
        assertEq(deadline, block.number + 25, "Maintenance deadline should be block + 25 (tighter)");
    }
    
    function testSuccessfulMaintenance() public {
        _completeInitialVerification(agent1);
        
        ProofOfIntelligenceV2.PoICredential memory credBefore = poi.getCredential(agent1);
        uint256 oldExpiry = credBefore.expiresAt;
        
        // Fast forward to maintenance window
        vm.warp(block.timestamp + 5 days + 1);
        
        // Request and complete maintenance
        _completeMaintenance(agent1);
        
        // Check credential was renewed
        ProofOfIntelligenceV2.PoICredential memory credAfter = poi.getCredential(agent1);
        
        assertGt(credAfter.expiresAt, oldExpiry, "Expiry should be extended");
        assertEq(credAfter.maintenanceCount, 1, "Maintenance count should be 1");
        assertEq(credAfter.reputation, 55, "Reputation should increase by 5");
    }
    
    function testMultipleMaintenance() public {
        _completeInitialVerification(agent1);
        
        // Do 3 maintenance cycles
        for (uint i = 0; i < 3; i++) {
            // Forward to maintenance window
            vm.warp(block.timestamp + 5 days + 1 hours);
            _completeMaintenance(agent1);
        }
        
        ProofOfIntelligenceV2.PoICredential memory cred = poi.getCredential(agent1);
        assertEq(cred.maintenanceCount, 3, "Should have 3 maintenance renewals");
        assertEq(cred.reputation, 65, "Reputation should be 50 + (3 * 5)");
    }
    
    function testReputationCap() public {
        _completeInitialVerification(agent1);
        
        // Do many maintenance cycles to try to exceed 100 rep
        for (uint i = 0; i < 15; i++) {
            vm.warp(block.timestamp + 5 days + 1 hours);
            _completeMaintenance(agent1);
        }
        
        ProofOfIntelligenceV2.PoICredential memory cred = poi.getCredential(agent1);
        assertEq(cred.reputation, 100, "Reputation should cap at 100");
    }
    
    // ============ Decay Tests ============
    
    function testDecayAfterGracePeriod() public {
        _completeInitialVerification(agent1);
        
        // Fast forward past expiry + grace period
        vm.warp(block.timestamp + 8 days + 1);
        
        // Anyone can trigger decay
        poi.triggerDecay(agent1);
        
        // Credential should be decayed
        ProofOfIntelligenceV2.PoICredential memory cred = poi.getCredential(agent1);
        assertFalse(cred.valid, "Should be invalid after decay");
        assertEq(cred.reputation, 0, "Reputation should be 0 after decay");
    }
    
    function testCantMaintainDecayedCredential() public {
        _completeInitialVerification(agent1);
        
        // Fast forward past grace period
        vm.warp(block.timestamp + 8 days + 1);
        
        // Try to maintain
        vm.prank(agent1);
        vm.expectRevert(ProofOfIntelligenceV2.CredentialAlreadyDecayed.selector);
        poi.requestMaintenanceChallenge();
    }
    
    // ============ Stats Tests ============
    
    function testStats() public {
        // Initial verification
        _completeInitialVerification(agent1);
        
        // Failed attempt
        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(agent2);
        poi.requestChallenge();
        
        // Submit wrong answer - returns false, doesn't revert
        bool success = poi.submitAnswer(bytes32(uint256(99999)));
        assertFalse(success, "Should fail");
        vm.stopPrank();
        
        (uint256 issued, uint256 passed, uint256 failed,,) = poi.getStats();
        assertEq(issued, 2, "2 challenges issued");
        assertEq(passed, 1, "1 passed");
        assertEq(failed, 1, "1 failed");
    }
    
    // ============ Helper Functions ============
    
    function _completeInitialVerification(address agent) internal {
        vm.startPrank(agent);
        (bytes32 seed, uint8 challengeType,) = poi.requestChallenge();
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent);
        poi.submitAnswer(answer);
        vm.stopPrank();
    }
    
    function _completeMaintenance(address agent) internal {
        vm.startPrank(agent);
        (bytes32 seed, uint8 challengeType,) = poi.requestMaintenanceChallenge();
        bytes32 answer = poi.computeExpectedAnswer(challengeType, seed, agent);
        poi.submitAnswer(answer);
        vm.stopPrank();
    }
}
