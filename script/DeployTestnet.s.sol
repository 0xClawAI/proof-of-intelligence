// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ProofOfIntelligence.sol";
import "../src/MockAgentRegistry.sol";

contract DeployTestnetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock registry
        MockAgentRegistry registry = new MockAgentRegistry();
        console.log("MockAgentRegistry deployed to:", address(registry));
        
        // Register the deployer as an agent (for testing)
        registry.registerAgent(deployer);
        console.log("Registered deployer as agent:", deployer);
        
        // Deploy PoI with mock registry
        ProofOfIntelligence poi = new ProofOfIntelligence(address(registry));
        console.log("ProofOfIntelligence deployed to:", address(poi));
        
        vm.stopBroadcast();
    }
}
