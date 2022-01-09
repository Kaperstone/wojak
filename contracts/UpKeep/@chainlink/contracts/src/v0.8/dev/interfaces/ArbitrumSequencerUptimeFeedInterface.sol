// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ArbitrumSequencerUptimeFeedInterface {
  function updateStatus(bool status, uint64 timestamp) external;
}
