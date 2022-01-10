// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    function deposit() external;
    function withdraw() external;
    function burn() external;
}