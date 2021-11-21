// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";
import "./Pancakeswap.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    uint256 public liquidityFee = 50; // 2%
    uint256 public treasuryFee = 50; // 2%
    uint256 public burningFee = 0; // 0% Initially disabled

    // Pancakeswap v2
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public treasuryAddress;
    address public bondsAddress;
    address public vaultAddress;
    address public ovenAddress;
    address public stakingAddress;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
    **/
    function _transfer(
        address sender,
        address recipient,
        uint256 brutto
    ) internal virtual {
        // When interacting with the treasury, bonds, staking, oven, vault or this contract
        if(
            sender == address(treasuryAddress) || recipient == address(treasuryAddress) ||
            sender == address(bondsAddress) || recipient == address(bondsAddress) ||
            sender == address(ovenAddress) || recipient == address(ovenAddress) ||
            sender == address(stakingAddress) || recipient == address(stakingAddress) ||
            sender == address(this) || recipient == address(this) ||
            sender == address(vaultAddress) || recipient == address(vaultAddress)
        ) {
                        // if this is
            require(sender != address(0), "ERC20: transfer from the zero address");
            require(recipient != address(0), "ERC20: transfer to the zero address");

            _beforeTokenTransfer(sender, recipient, brutto);

            uint256 senderBalance = _balances[sender];
            require(senderBalance >= brutto, "ERC20: transfer amount exceeds balance");
            unchecked {
                _balances[sender] = senderBalance - brutto;
            }
            _balances[recipient] += brutto;

            emit Transfer(sender, recipient, brutto);

            _afterTokenTransfer(sender, recipient, brutto);
        }else{
            require(sender != address(0), "ERC20: transfer from the zero address");
            require(recipient != address(0), "ERC20: transfer to the zero address");

            _beforeTokenTransfer(sender, recipient, brutto);

            // TAX
            uint8 splits = 0;
            // Need to do the math before calling external functions

            uint256 _liquidityFee = 0;
            if(liquidityFee != 0) {
                _liquidityFee = brutto / liquidityFee;
                splits++;
            }
            uint256 _treasuryFee = 0;
            if(treasuryFee != 0) {
                _treasuryFee = brutto / treasuryFee;
                splits++;
            }
            uint256 _burningFee = 0;
            if(burningFee != 0) { // If activated
                _burningFee = brutto / burningFee;
                splits++;
            }

            uint fee = _liquidityFee + _treasuryFee + _burningFee;

            // Lets deduct the fees from the initial amount
            uint netto = brutto - fee;
            // This is netto
            

            // We tight these functions together.
            uint256 senderBalance = _balances[sender];
            require(senderBalance >= brutto, "ERC20: transfer amount exceeds balance");
            unchecked {
                _balances[sender] = senderBalance - brutto; // Sender is being deducted by full amount
                _balances[address(this)] += fee; // Add to the contract's balance
            }
            _balances[recipient] += netto; // Recipient receives netto (after tax)

            // Lets take a clean sheet, we take the contract's balance and split it into three
            uint slices = balanceOf(address(this)) / splits;

            // Liquidity
            if(liquidityFee != 0) {
                uint initialBNBBalance = address(this).balance;
                uint TwoHalfs = slices / 2;
                // Half is converted to BNB
                swapTokensForEth(TwoHalfs); // Half to BNB
                // The other half stays in the token form
                // And then we should get exactly the same amount of tokens.
                addLiquidity(TwoHalfs, (address(this).balance - initialBNBBalance));
            }

            // Treasury tax
            if(treasuryFee != 0) {
                swapTokensForEth(slices); // Turn the fee into BNB
                // And then just send BNB to the treasury
                address(treasuryAddress).call{ value: address(this).balance };
            }
            
            // Burning
            if(burningFee != 0) _burn(sender, slices); // Burn the fee from the source

            emit Transfer(sender, recipient, brutto);

            _afterTokenTransfer(sender, recipient, brutto);
        }
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}


    
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapRouter.WETH();

        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        // add the liquidity
        pancakeswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

    }

    function _updateTreasuryAddress(address newAddress) internal virtual {
        require(newAddress != treasuryAddress, "This is the same address!");
        treasuryAddress = newAddress;
    }
    function _updateBondsAddress(address newAddress) internal virtual {
        require(newAddress != bondsAddress, "This is the same address!");
        bondsAddress = newAddress;
    }
    function _updateVaultAddress(address newAddress) internal virtual {
        require(newAddress != vaultAddress, "This is the same address!");
        vaultAddress = newAddress;
    }
    function _updateOvenAddress(address newAddress) internal virtual {
        require(newAddress != ovenAddress, "This is the same address!");
        ovenAddress = newAddress;
    }
    function _updateStakingAddress(address newAddress) internal virtual {
        require(newAddress != stakingAddress, "This is the same address!");
        stakingAddress = newAddress;
    }

    function _setLiquidityFee(uint256 fee) internal virtual {
        liquidityFee = fee;
    }

    function _setTreasuryFee(uint256 fee) internal virtual {
        treasuryFee = fee;
    }

    function _setBurningFee(uint256 fee) internal virtual {
        burningFee = fee;
    }

    // public view

    function getLiquidityFee() public view returns (uint256) {return liquidityFee;}
    function getTreasuryFee() public view returns (uint256) {return treasuryFee;}
    function getBurningFee() public view returns (uint256) {return burningFee;}

    function getTreasuryAddress() public view returns (address) {return treasuryAddress;}
    function getBondsAddress() public view returns (address) {return bondsAddress;}
    function getVaultAddress() public view returns (address) {return vaultAddress;}
    function getOvenAddress() public view returns (address) {return ovenAddress;}
    function getStakingddress() public view returns (address) {return stakingAddress;}

}


