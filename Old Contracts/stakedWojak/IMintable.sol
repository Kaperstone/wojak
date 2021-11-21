// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMinter {
    function getMinter() external view returns (address);
    function transferMinter(address newOwner_) external;
}