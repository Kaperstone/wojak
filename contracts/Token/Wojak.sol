// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

import "./iWojak.sol";
import "./../_lib/Common.sol";

abstract contract Wojak is Common, iWojak, ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public treasury = address(0);

    // Excluded list
    address[] internal excluded;

    constructor(bool testnet) ERC20("Wojak", "WJK", testnet) {
        _mint(msg.sender, 700 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        if(testnet) {
            BUSD = IERC20(address(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee));
            WBNB = IERC20(address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd));
        }else{
            BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));
            WBNB = IERC20(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
        }
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

            uint fee = onePercent * 2;

            // Lets deduct the fees from the initial amount + deduct a burn
            uint netto = brutto - fee - onePercent;
            
            unchecked {
                _balances[sender] = senderBalance - brutto; // Sender is being deducted by full amount
                _balances[address(this)] += fee; // Add to the contract's balance
            }

            // Someone just executed "_approve", it attempts to empty the contract of BNB, WBNB and BUSD tokens
            if(transferringLeftovers) {
                // So instead of creating LP or swapping for BUSD to fill the treausry, we just burn the tokens, so the tax don't go to waste
                netto -= onePercent * 2;
            }else{

                // Liquidity
                if(!swapLock) {
                    swapAndLiquify(onePercent);
                }else{
                    // If cannot we cannot exchange currently, then burn
                    // Otherwise it will be lost to frontrun
                    netto -= onePercent;
                }
                // Treasury tax
                swapTokensForBUSD(onePercent); // Turn the fee into BUSD
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

    function _addExcluded(address excludeAddress) public onlyRole(ADMIN_ROLE) {
        (bool _isExcluded, ) = isExcluded(excludeAddress);
        if(!_isExcluded) excluded.push(excludeAddress);
    }

    function _removeExcluded(address excludeAddress) public onlyRole(ADMIN_ROLE) {
        (bool _isExcluded, uint x) = isExcluded(excludeAddress);
        if(_isExcluded) {
            excluded[x] = excluded[excluded.length - 1];
            excluded.pop();
        } 
    }

    function setRouterAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        pancakeswapRouter = IUniswapV2Router02(newAddress);
    }
    
    function setTreasuryAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        treasury = address(newAddress);
    }

    function setBUSDAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        BUSD = IERC20(address(newAddress));
    }

    function setWBNBAddress(address newAddress) public onlyRole(ADMIN_ROLE) {
        BUSD = IERC20(address(newAddress));
    }

    uint lastTransferLeftovers = block.timestamp;
    function donateToTreasury() public {
        // Because I know people might abuse the shit out of this function :facepalm:
        require(block.timestamp - lastTransferLeftovers > 86400, "!toosoon");
        lastTransferLeftovers = block.timestamp;
        // We need to lock all the LP and Treasury tax, so we don't accidently distrupt an attempt to add LP
        transferringLeftovers = true;
        // Empty the contract of BNB, WBNB and BUSD
        if(address(this).balance > 0) {
            address(treasury).call{ value: address(this).balance };
        }

        if(BUSD.balanceOf(address(this)) > 0) {
            BUSD.transfer(address(treasury), BUSD.balanceOf(address(this)));
        }

        if(WBNB.balanceOf(address(this)) > 0) {
            WBNB.transfer(address(treasury), WBNB.balanceOf(address(this)));
        }
        transferringLeftovers = false;
    }
}
