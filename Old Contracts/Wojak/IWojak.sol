// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWojak {
    function mintFor(address account, uint256 amount) external;
    function burnFor(address account, uint256 amount) external returns (bool);
    function burnForMe(uint256 amount) external returns (bool);
}