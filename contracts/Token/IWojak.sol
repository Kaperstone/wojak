// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface Wojak {
    function requestMintedForStaking() external returns (uint256);
    function requestMintedForBonds() external returns (uint256);
    function requestMintedForTreasury() external returns (uint256);
    function updateTreasuryAddress(address newAddress) external;
    function updateBondsAddress(address newAddress) external;
    function updateOvenAddress(address newAddress) external;
    function updateStakingAddress(address newAddress) external;
    function setLiquidityFee(uint256 fee) external;
    function setTreasuryFee(uint256 fee) external;
    function setBurningFee(uint256 fee) external;
    function requestQuarterIncreaseInInflation() external;
    function requestQuarterDecreaseInInflation() external;
    function burnForMeEverything() external;
    function burnForMe(uint256 amount) external;
    function activateTreasurySellMinting() external;
    function deactivateTreasurySellMinting() external;
    function setStakingExecuterReward(uint256 newReward) external;
}