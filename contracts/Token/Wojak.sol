// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

import "./iWojak.sol";

abstract contract Wojak is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(bool testnet) ERC20("Wojak", "WJK", testnet) {
        _mint(msg.sender, 700 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burnEverything() public {
        burn(balanceOf(msg.sender));
    }

    function addExclusion(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _addExcluded(excludeAddress);
    }

    function removeExclusion(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeExcluded(excludeAddress);
    }

    function setRouterAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRouterAddress(newAddress);
    }
    
    function setTreasuryAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryAddress(newAddress);
    }

    function setWBNBAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setWBNBAddress(newAddress);
    }

    function setBUSDAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBUSDAddress(newAddress);
    }
}
