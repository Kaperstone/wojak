// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/IERC20.sol";

interface ISoyFarms is IERC20 {
    function deposit(uint busdAmount) external;
    function withdraw(uint soyAmount) external;
    function farmerBalance(address _farmer) external view returns (uint256, uint256);
    function distributeRewards() external;
    function takeIncome() external returns (uint256);
    function calculateRevenue() external view returns (uint256);
    function isFarmer(address _address) external view returns(bool, uint);
}