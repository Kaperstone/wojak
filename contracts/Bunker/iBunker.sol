// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface Bunker {
    function addToTreasury() external;
    function fixWBNBtoBNB() external;
    function withdrawUselessToken() external;
    function getBUSDTreasury() external;
    function getConvertedBNB() external;
    function heatOven() external;
    function setPancakeAddress(address newAddress) external;
    function setTokenAddress(address newAddress) external;
    function setWBNBAddress(address newAddress) external;
    function setvenusBUSDAddress(address newAddress) external;
    function setBUSDAddress(address newAddress) external;
    function setUnitrollerAddress(address newAddress) external;
    function updateBondAddress(address newAddress) external;
}