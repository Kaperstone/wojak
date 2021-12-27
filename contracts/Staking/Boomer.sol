// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 * Staking
 * _mint here should be removed here permenanetly
 * The function takes rewards from the [token] contract and splits it among stakers proportionally
 *
**/

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/utils/SafeERC20.sol";
import "./@openzeppelin/contracts/utils/Pancakeswap.sol";

import "./iBoomer.sol";

abstract contract Boomer is ERC20, ERC20Burnable, AccessControl {
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    // Array to collect all the stakeholders addresses
    address[] internal stakeholders;
    mapping(address => uint256) public stakeLock; 

    // Shorthands for calls
    IBEP20 public token = IBEP20(address(0));
    IBEP20 public bond = IBEP20(address(0));
    IBEP20 public treasury = IBEP20(address(0));

    uint public lastStakingRewardsTimestamp = block.timestamp;
    uint public lastDistributedRewards = 0;
    uint public totalRewards = 0;

    uint fillAmount = 1;

    // Pancakeswap v2
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(address(0));

    constructor() ERC20("Boomer", "BMR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ---------- STAKES ----------

    function Stake(uint amount) public {
        // We transfer his tokens to the smart contract, its now in its posession
        require(token.transferFrom(msg.sender, address(this), amount), "Unable to stake");
        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, amount); // Mint Boomer tokens to his account
        stakeLock[msg.sender] = block.timestamp + 86400;
        // If its a new address, welcome to the staking pool
        if(balanceOf(msg.sender) == 0) addStakeholder(msg.sender); // New unique staker account
    }

    function Unstake(uint amount) public {
        require(block.timestamp > stakeLock[msg.sender], "You cannot unstake yet, 24 hours must pass since last stake-in");
        uint amountHave = balanceOf(msg.sender);
        // He requests back more than he can
        require(amount > amountHave, "No tokens to unstake");

        // We burn his Boomers
        _burn(msg.sender, amountHave);

        // Give him his tokens from this contract
        token.transfer(msg.sender, amountHave);
        
        // Remove him from the array if he holds 0 tokens
        if(balanceOf(msg.sender) == 0) removeStakeholder(msg.sender);
    }

    // ---------- STAKEHOLDERS ----------

    function isStakeholder(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < stakeholders.length; x++){
            if (_address == stakeholders[x]) return (true, x);
        }
        return (false, 0);
    }

    function addStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }

    function removeStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, uint x) = isStakeholder(_stakeholder);
        if(_isStakeholder) {
            stakeholders[x] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        } 
    }

    // ---------- REWARDS ----------

    // Externally it can be used for `Next reward yield`
    function calculateReward(address _stakeholder) public view returns (uint) {
        // New model is to give 0.25% of what he is holding
        return balanceOf(_stakeholder) / 400;
        // It is also auto-compounding :)
    }

    // Distribute once per 24 hours
    function distributeRewards() public onlyRole(KEEPER_ROLE) {
        require((lastStakingRewardsTimestamp - block.timestamp) > 21600, "Staking rewards are distributed only once per 24 hours");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 21600;

        uint lTotalRewards = 0;
        for(uint x = 0; x < stakeholders.length; x++) {
            uint Reward = calculateReward(stakeholders[x]);
            lTotalRewards += Reward;
            _mint(msg.sender, Reward * 10**18);
        }

        // In one run
        token.mint(address(this), lTotalRewards * 10**18);

        // For statistics
        lastDistributedRewards = lTotalRewards;
        totalRewards += lTotalRewards;
        
        // For bond average price
        bond.updateTokenPriceAtStaking();

        // This is the place to automate the usage of this, because nobody else would do
        treasury.addToTreasury();
        
        // We need to get that treasury grow!
        if(fillAmount > 0) {
            // Mint some tokens to fill the treasury
            token.mint(address(this), fillAmount * 2 * 10**18);

            // Sell half to get BUSD
            swapTokensForBUSD(fillAmount * 10**18);
            // Send the BUSD to treasury

            swapAndLiquify(fillAmount / 2);
        }
    }

    function setFillAmount(uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fillAmount = amount;
    }

    function setTokenAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IBEP20(newAddress);
    }

    function setBondAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bond = IBEP20(newAddress);
    }

    function setTreasuryAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = IBEP20(newAddress);
    }
    
    function setRouterAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pancakeswapRouter = IUniswapV2Router02(newAddress);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half); 
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapRouter.WETH();

        token.approve(address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        token.approve(address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(treasury), // Give the LP tokens to the treasury
            block.timestamp
        );
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address target, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    function setTokenAddress(address newAddress) external;
    function setBondAddress(address newAddress) external;
    function setTreasuryAddress(address newAddress) external;
    function setRouterAddress(address newAddress) external;

    function heatOven() external;
    function addToTreasury() external;

    function updateTokenPriceAtStaking() external;
}