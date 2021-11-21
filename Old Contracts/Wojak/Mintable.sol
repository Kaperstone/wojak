// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMintable.sol";
import "./Ownable.sol";

contract Mintable is Ownable {
    address internal minter;

    event MinterTransferred(address indexed previousMinter, address indexed newMinter);

    constructor() {
        minter = msg.sender;
        emit MinterTransferred(address(0), minter);
    }

    function getMinter() public view override returns (address) {
        return minter;
    }

    modifier onlyMinter() {
        require(minter == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferMinter(address newMinter) public virtual onlyOwner() {
        require(newMinter != address(0), "Ownable: new owner is the zero address");
        emit MinterTransferred(minter, newMinter);
        minter = newMinter;
    }
}