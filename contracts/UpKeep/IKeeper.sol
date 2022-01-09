// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKeeper {
    function adminCheckUp() external view returns (bool upkeepNeeded);
}