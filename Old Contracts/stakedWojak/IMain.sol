// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IsWojak {

    // Staking functions
    function Stake(uint256 amount) external;
    function Unstake(uint256 _stake) external;
    function isStakeholder(address _address) external view returns(bool, uint256);
    function stakeOf(address _stakeholder) external view returns(uint256);
    function totalStakes() external view returns(uint256);

    // Rewards
    function withdrawReward() external;


    function distributeRewards() external;
    function getLastStakingRewards() external view returns (uint256);
}