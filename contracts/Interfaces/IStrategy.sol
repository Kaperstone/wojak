// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    function deposit() external;
    function withdraw() external;
    function burn() external;

    function setAddressToken(address newAddress) external;
    function setAddressStaking(address newAddress) external;
    function setAddressTreasury(address newAddress) external;
    function setAddressSoyFarm(address newAddress) external;
}