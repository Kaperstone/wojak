// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface iBoomer {
    
    function Stake(uint amount) external;
    function Unstake(uint amount) external;
    function isStakeholder(address _address) external;
    function calculateReward(address _stakeholder) external;
    function distributeRewards() external;
    function getLastStakingRewardsTimestamp() external;
    function getLastDistributedRewards() external;
    function updateTokenAddress(address newAddress) external;
    function updateBondAddress(address newAddress) external;
    function getIndex() external;
}