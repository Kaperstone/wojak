// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface Wojak {
    function requestMintedForStaking() external returns (uint256);
    function requestMintedForBonds() external returns (uint256);
    function requestMintedForVaults() external returns (uint256);
    function updateTreasuryAddress(address newAddress) external;
    function updateBondsAddress(address newAddress) external;
    function updateVaultAddress(address newAddress) external;
    function updateOvenAddress(address newAddress) external;
    function updateStakingAddress(address newAddress) external;
    function setLiquidityFee(uint256 fee) external;
    function setTreasuryFee(uint256 fee) external;
    function setBurningFee(uint256 fee) external;
}