// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/IERC20.sol";

interface IBoomer is IERC20 {
    function Stake(uint wjkAmount) external returns (uint256);
    function Unstake(uint amount) external returns (uint256);
    function stakerBalance(address _stakeholder) external view returns (uint256);
    function distributeRewards() external;
    function setFillAmount(uint amount) external;
}