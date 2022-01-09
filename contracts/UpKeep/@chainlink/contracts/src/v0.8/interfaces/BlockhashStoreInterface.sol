// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface BlockhashStoreInterface {
  function getBlockhash(uint256 number) external view returns (bytes32);
}
