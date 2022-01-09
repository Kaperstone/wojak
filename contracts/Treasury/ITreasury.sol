// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ITreasury {
    function addToTreasury() external;
    function get() external;
    function put() external;
    function changeTreasuryContract(address newContract) external;
}