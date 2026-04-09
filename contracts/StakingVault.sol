// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StakingVault {

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTime;

    function stake() external payable {
        require(msg.value > 0, "Must send ETH");

        balances[msg.sender] += msg.value;
        depositTime[msg.sender] = block.timestamp;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        uint256 duration = block.timestamp - depositTime[msg.sender];
        uint256 reward = (amount * duration) / 1000;

        balances[msg.sender] = 0;

        payable(msg.sender).transfer(amount + reward);
    }
}
