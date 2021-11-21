// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITreasury {
    function changePairAddress(address newAddress) external;
    function getTreasuryTotalStable() external view returns (uint256);
    function getTreasuryTotalBNB() external view returns (uint256);
    function getTreasuryTotalLP() external view returns (uint256);
    function checkSmartContractForLeftovers() external;
    function withdrawUselessToken(address tokenAddress) external;
}