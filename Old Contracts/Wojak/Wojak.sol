// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** 
 *
 *  KADET smart contract - Token itself
 *  Where the magic isn't happening.
 *  We literally just import all the necessary files here.
 *  That's the entire point. finito.
 *
**/

import "./SafeMath.sol";

import "./Interface.sol";
import "./IERC20.sol";
import "./IWojak.sol";
import "./Pancakeswap.sol";
import "./ITreasury.sol";
import "./IBurnEvent.sol";

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Mintable.sol";

import "./LiquidityBooster.sol";
import "./Bonds.sol";

// import "./Staking.sol"; // A friend of ours left the smart contract and decided to live alone.

contract WojakContract is Ownable, Mintable, Bonds, LiquidityBooster, IERC20, ITreasury, IBurnEvent {
    using SafeMath for uint256;


    // ERC20 variables
    IUniswapV2Router02 public pancakeswapRouter;
    address public treasuryAddress;


    constructor() {
        ERC20("Wojak", "WJK", 18);
    }

    function mintFor(address account, uint256 amount) public onlyMinter() {
       _mint(account, amount); 
    }

    function burnFor(address account, uint256 amount) public onlyMinter() returns (bool) {
        require(_burn(account, amount), "Burn not possible");
        return true;
    }

    function burnForMe(uint256 amount) public returns (bool) {
        require(_burn(msg.sender, amount), "Burn not possible");
        return true;
    }

    // Treasury

    // BURN BABY, BURN


    // ERC20

    function ERC20(string memory name_, string memory symbol_, uint8 decimals_) private {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        
        treasuryAddress = msg.sender;

        // Pancake Router Testnet v1
        // IUniswapV2Router02 _pancakeswapRouter = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

        // Pancakeswap Router Mainnet v2
        pancakeswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function name() public view returns (string memory) {return _name;}
    function symbol() public view returns (string memory) {return _symbol;}
    function decimals() public view override returns (uint8) {return _decimals;}
    function totalSupply() public view override returns (uint256) {return _totalSupply;}
    function balanceOf(address account) public view virtual override returns (uint256) {return _balances[account];}

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {return _allowances[owner][spender];}
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount ) internal virtual notZeroAddress(sender) notZeroAddress(recipient) {
        if(msg.sender != address(this)) {
            // Liquidity tax
            uint256 _liquidityFee = amount.div(liquidityFee);
            uint256 initialBalance = address(this).balance;
            swapTokensForEth(_liquidityFee);
            uint256 bnbBalance = address(this).balance.sub(initialBalance);
            addLiquidity(_liquidityFee, bnbBalance);

            // Treasury tax
            uint256 _treasuryFee = amount.div(treasuryFee);
            swapTokensForEth(_liquidityFee);
            // GlobalAddToTreasury("BNB", address(this).balance);
            
            uint256 _resaleFee = 0;
            if(resaleFee != 0) {}

            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(amount - _liquidityFee - _treasuryFee - _resaleFee);
            emit Transfer(sender, recipient, amount);
        }else{
            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(amount);
            emit Transfer(sender, recipient, amount);
        }
    }

    function _mint(address account_, uint256 amount_) internal virtual notZeroAddress(account_) {
        _totalSupply = _totalSupply.add(amount_);
        _balances[account_] = _balances[account_].add(amount_);
        emit Transfer(address(this), account_, amount_);
    }

    function _burn(address account, uint256 amount) internal virtual notZeroAddress(account) returns (bool) {
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual notZeroAddress(owner) notZeroAddress(spender) {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    modifier notZeroAddress(address addr) {
        require(addr != address(0), "ERC20: zero address");
        _;
    }

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

    function updatePancakeswapAddress(address newAddress) external onlyOwner() {
        require(newAddress != address(pancakeswapRouter), "The router already has that address");
        pancakeswapRouter = IUniswapV2Router02(newAddress);
    }

    function updateTreasuryAddress(address newAddress) external onlyOwner() {
        require(newAddress != treasuryAddress, "This is the same address!");
        treasuryAddress = newAddress;
    }

    function getLiquidityFee() public view returns (uint256) {
        return liquidityFee;
    }
    function setLiquidityFee(uint256 fee) public onlyOwner() {
        liquidityFee = fee;
    }

    function getTreasuryFee() public view returns (uint256) {
        return treasuryFee;
    }
    function setTreasuryFee(uint256 fee) public onlyOwner() {
        treasuryFee = fee;
    }

    function getResaleFee() public view returns (uint256) {
        return resaleFee;
    }
    function setResaleFee(uint256 fee) public onlyOwner() {
        resaleFee = fee;
    }
}