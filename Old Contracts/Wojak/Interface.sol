// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    function balanceOf(address _owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function withdraw(uint wad) external;
}

interface IVault {
    function deposit(uint256 amount) external;
}

interface VBep20 {
    function mint(uint mintAmount) external returns (uint);
}