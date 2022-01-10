// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../Common.sol";

abstract contract Wojak is Common, ERC20 {
    event Tax(uint busdRevenue, uint taxSize);
    event Mint(address to, uint amount);

    // Excluded list
    address[] internal excluded;

    constructor() ERC20("Wojak", "WJK") Common() {
        // Developer tokens
        _mint(msg.sender, 1200 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {

        // Check if its not one of our contracts that is trying to transfer
        (bool senderExcluded, ) = isExcluded(from);
        (bool recipientExcluded, ) = isExcluded(to);
        if(!senderExcluded && !recipientExcluded) {
            uint onePercent = amount / 100;

            // Burn 3% off his account
            _burn(address(to), onePercent * 3);

            // Mint 2% to this contract and then sell it
            _mint(address(this), onePercent * 2);
            uint busd = swap(address(WJK), address(BUSD), onePercent*2, address(keeper));
            emit Tax(busd, onePercent);
        }
    }


    function isExcluded(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < excluded.length; x++){
            if (_address == excluded[x]) return (true, x);
        }
        return (false, 0);
    }

    function addExcluded(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool _isExcluded, ) = isExcluded(excludeAddress);
        if(!_isExcluded) excluded.push(excludeAddress);
    }

    function removeExcluded(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool _isExcluded, uint x) = isExcluded(excludeAddress);
        if(_isExcluded) {
            excluded[x] = excluded[excluded.length - 1];
            excluded.pop();
        } 
    }
}
