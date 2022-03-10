// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract Wojak is ERC20, AccessControlEnumerable {
    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    uint public totalBurnt = 0;

    constructor() ERC20("Wojak", "WJK") {
        // Send all the supply to the developer for distribution
        _mint(msg.sender, 100000000 * 10 ** decimals());

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Staking only
    function mint(address to, uint amount) public onlyRole(CONTRACT_ROLE) {
        _mint(to, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
        totalBurnt += amount;
    }
}
