// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/ERC20.sol";

import "../_lib/Common.sol";

abstract contract Wojak is Common, ERC20 {
    using SafeERC20 for IERC20;

    // Excluded list
    address[] internal excluded;

    constructor(bool testnet) ERC20("Wojak", "WJK") Common(testnet) {
        // Developer tokens
        _mint(msg.sender, 1200 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _transfer(address sender, address recipient, uint256 brutto) internal override virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, brutto);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= brutto, "ERC20: transfer amount exceeds balance");

        // When interacting with the treasury, bonds and others are suppose to be excluded
        (bool senderExcluded, ) = isExcluded(sender);
        (bool recipientExcluded, ) = isExcluded(recipient);
        if(senderExcluded || recipientExcluded) {
            unchecked {
                _balances[sender] = senderBalance - brutto;
            }
            _balances[recipient] += brutto;
        }else{
            uint onePercent = brutto / 100;

            // Exclude 1% which goes to burn
            uint fee = onePercent * 2;

            // Lets deduct the fees from the initial amount + deduct the 1% burn
            uint netto = brutto - fee - onePercent;
            
            unchecked {
                _balances[sender] = senderBalance - brutto; // Sender is being deducted by full amount
                _balances[address(this)] += fee; // Add to the contract's balance
            }

            // Someone just executed donation to the treausry :D
            // it attempts to empty the contract of BNB, WBNB and BUSD tokens
            if(transferringLeftovers) {
                // So instead of creating LP or swapping for BUSD to fill the treausry, we just burn the tokens, so the tax don't go to waste
                netto -= onePercent * 2;
            }else{
                // Send to the Keeper, it will then use this fee to supply itself with enough LINK and fill the liquidity as well as the treasury.
                swap(address(WJK), address(BUSD), onePercent*2, address(keeper));
            }

            _balances[recipient] += netto; // Recipient receives netto (after tax)
            // We decrease the total supply, because we burnt some
            _totalSupply -= brutto - netto;
        }
        emit Transfer(sender, recipient, brutto);
        _afterTokenTransfer(sender, recipient, brutto);
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
