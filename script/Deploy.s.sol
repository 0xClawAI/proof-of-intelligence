// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ProofOfIntelligence.sol";

contract DeployScript is Script {
    function run() external {
        // ERC-8004 Agent Registry on Mainnet
        // For testnet, we'll use the same address (it exists on mainnet, 
        // but for Base Sepolia testing we might need to deploy a mock)
        address agentRegistry = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        ProofOfIntelligence poi = new ProofOfIntelligence(agentRegistry);
        
        console.log("ProofOfIntelligence deployed to:", address(poi));
        console.log("Agent Registry:", agentRegistry);
        
        vm.stopBroadcast();
    }
}
