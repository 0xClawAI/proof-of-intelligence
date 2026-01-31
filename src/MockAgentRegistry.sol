// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockAgentRegistry
 * @notice Mock ERC-8004 registry for testing on testnets
 */
contract MockAgentRegistry {
    mapping(address => uint256) public balances;
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function registerAgent(address agent) external {
        balances[agent] = 1;
    }
    
    function balanceOf(address agent) external view returns (uint256) {
        return balances[agent];
    }
}
