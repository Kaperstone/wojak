// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBurnEvent {
    function startBurnEvent() external;
    function getTotalTokensBurnt() external view returns (uint256);
    function getLastBurnEventTimestamp() external view returns (uint256);
}