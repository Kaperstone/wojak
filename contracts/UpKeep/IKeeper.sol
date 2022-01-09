// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IKeeper {
    function simpleUpKeepCheck() external view returns (bool upkeepNeeded);
}