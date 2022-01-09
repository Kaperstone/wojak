// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBoomer is IERC20 {
    function stake(uint wjkAmount) external returns (uint256);
    function unstake(uint amount) external returns (uint256);
    function burn(uint amount) external;
    function stakerBalance(address _stakeholder) external view returns (uint256);
    function distributeRewards() external;
    function setFillAmount(uint amount) external;
}