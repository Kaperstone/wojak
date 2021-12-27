// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";
import "../../utils/Pancakeswap.sol";

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
abstract contract ERC20 is Context, IERC20, IERC20Metadata {
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    
    bool swapLock = false;

    // Pancakeswap v2
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(address(0));

    address public treasury = address(0);

    // Excluded list
    address[] internal excluded;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    IERC20 public BUSD = IERC20(address(0));
    IERC20 public WBNB = IERC20(address(0));

    bool transferringLeftovers = false;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, bool testnet) {
        _name = name_;
        _symbol = symbol_;

        if(testnet) {
            BUSD = IERC20(address(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee));
            WBNB = IERC20(address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd));
        }else{
            BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));
            WBNB = IERC20(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
        }
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
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
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


    
    function swapAndLiquify(uint256 contractTokenBalance) private {
        swapLock = true;
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half); 
        uint256 newBalance = address(this).balance - initialBalance;
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
        swapLock = false;
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapRouter.WETH();

        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForBUSD(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(BUSD);

        _approve(address(this), address(pancakeswapRouter), amount);

        pancakeswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            address(treasury),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(treasury), // Give the LP tokens to the treasury
            block.timestamp
        );
    }

    function isExcluded(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < excluded.length; x++){
            if (_address == excluded[x]) return (true, x);
        }
        return (false, 0);
    }

    function _addExcluded(address excludeAddress) internal {
        (bool _isExcluded, ) = isExcluded(excludeAddress);
        if(!_isExcluded) excluded.push(excludeAddress);
    }

    function _removeExcluded(address excludeAddress) internal {
        (bool _isExcluded, uint x) = isExcluded(excludeAddress);
        if(_isExcluded) {
            excluded[x] = excluded[excluded.length - 1];
            excluded.pop();
        } 
    }

    function _setRouterAddress(address newAddress) internal {
        pancakeswapRouter = IUniswapV2Router02(newAddress);
    }
    
    function _setTreasuryAddress(address newAddress) internal {
        treasury = address(newAddress);
    }

    function _setBUSDAddress(address newAddress) internal {
        BUSD = IERC20(address(newAddress));
    }

    function _setWBNBAddress(address newAddress) internal {
        BUSD = IERC20(address(newAddress));
    }

    uint lastTransferLeftovers = block.timestamp;
    function TransferLeftovers() public {
        // Because I know people might abuse the shit out of this function :facepalm:
        require(block.timestamp - lastTransferLeftovers > 604800, "!toosoon");
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


