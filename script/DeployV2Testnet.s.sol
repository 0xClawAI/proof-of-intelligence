// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ProofOfIntelligenceV2.sol";
import "../src/MockAgentRegistry.sol";

contract DeployV2TestnetScript is Script {
    // Existing MockAgentRegistry from V1 deployment
    address constant EXISTING_REGISTRY = 0xE0b8fEfbBe7b041dEec12d2aF40A9aBA9A3018d4;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying PoI V2 with deployer:", deployer);
        console.log("Using existing registry:", EXISTING_REGISTRY);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PoI V2 with existing mock registry (reuse from V1)
        ProofOfIntelligenceV2 poiV2 = new ProofOfIntelligenceV2(EXISTING_REGISTRY);
        console.log("ProofOfIntelligenceV2 deployed to:", address(poiV2));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Network: Base Sepolia");
        console.log("MockAgentRegistry (reused):", EXISTING_REGISTRY);
        console.log("ProofOfIntelligenceV2:", address(poiV2));
        console.log("");
        console.log("Next: Run poi-client-v2.js to verify your agent!");
    }
}
