// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITreasury {
    function addToTreasury() external;
    function get() external;
    function put() external;
    function changeTreasuryContract(address newContract) external;

    function setAddressToken(address newAddress) external;
    function setAddressStaking(address newAddress) external;
    function setAddressTreasuryStrategy(address newAddress) external;
}