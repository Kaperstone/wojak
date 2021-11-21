// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMintable.sol";
import "./Ownable.sol";

contract Mintable is IMinter, Ownable {
    address internal _minter;

    event MinterTransferred(address indexed previousMinter, address indexed newMinter);

    constructor() {
        _minter = msg.sender;
        emit MinterTransferred(address(0), _minter);
    }

    function minter() public view returns (address) {
        return _minter;
    }

    modifier onlyMinter() {
        require(_minter == msg.sender, "Mintable: caller is not the owner");
        _;
    }

    function transferMinter(address newMinter) public virtual onlyOwner() {
        require(newMinter != address(0), "Ownable: new owner is the zero address");
        emit MinterTransferred(_minter, newMinter);
        _minter = newMinter;
    }
}