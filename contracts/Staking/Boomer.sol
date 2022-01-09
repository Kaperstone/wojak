// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./../_lib/contracts/token/ERC20/ERC20.sol";
import "./../_lib/contracts/utils/SafeERC20.sol";

import "../_lib/Common.sol";

abstract contract Boomer is Common, ERC20 {
    using SafeERC20 for IERC20;

    // Array to collect all the stakeholders locks
    mapping(address => uint256) public stakeLock; 
    // Last staking
    uint public lastStakingRewardsTimestamp = block.timestamp;
    // WJK balance as an array
    uint private wjkBalance = 0;

    // Administration
    uint public fillAmount = 1;

    // Statistics
    uint public totalRewards = 0;
    uint public busdCollectedForTreasury = 0;

    constructor(bool testnet) ERC20("Boomer Staking", "BOOMER") Common(testnet) {}

    // ---------- STAKES ----------

    function Stake(uint wjkAmount) public returns (uint256) {
        // We transfer his tokens to the smart contract, its now in its posession
        WJK.safeTransferFrom(msg.sender, address(this), wjkAmount);
        
        uint boomerAmount = wjkAmount / (_totalSupply / wjkBalance);
        wjkBalance += wjkAmount;

        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, boomerAmount); // Mint Boomer tokens to his account

        stakeLock[msg.sender] = block.timestamp + 86400;

        return boomerAmount;
    }

    function Unstake(uint amount) public returns(uint256) {
        require(block.timestamp > stakeLock[msg.sender], "You cannot unstake yet, 24 hours must pass since last stake-in");
        uint amountHave = balanceOf(msg.sender);
        // He requests back more than he can
        require(amount >= amountHave, "No tokens to unstake");

        // We burn his Boomers
        _burn(msg.sender, amount);
        uint wjkToSend = stakerBalance(msg.sender);
        wjkBalance -= wjkToSend;

        // Give him his tokens from this contract
        WJK.safeTransfer(msg.sender, wjkToSend);

        return wjkToSend;
    }

    // ---------- REWARDS ----------

    // Externally it can be used for `Next reward yield`
    function stakerBalance(address _stakeholder) public view returns (uint256) {
        // New model is to give 0.125% of what he is holding
        return balanceOf(_stakeholder) * (_totalSupply / wjkBalance);
        // It is also auto-compounding :)
    }

    // Distribute once per 24 hours
    function distributeRewards() public onlyRole(KEEPER_ROLE) {
        require((lastStakingRewardsTimestamp - block.timestamp) > 21600, "Staking rewards are distributed only once per 24 hours");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 21600;

        uint lTotalRewards = wjkBalance + (wjkBalance / 800); // We just raise the amount of wjk contract holds

        // Mint to the contract
        WJK.mint(address(this), lTotalRewards);

        // For statistics
        totalRewards += lTotalRewards;
        
        // We grow the treasury a little bit
        if(fillAmount > 0) {
            // Mint some tokens to fill the treasury
            WJK.mint(address(this), fillAmount * 2);

            // Sell half to get BUSD
            busdCollectedForTreasury += swap(address(WJK), address(WJK), fillAmount, address(treasury));
            // Send the BUSD to treasury

            swapAndLiquify(fillAmount);
        }
    }

    function setFillAmount(uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fillAmount = amount * 10**18;
    }

    function burn(uint amount) public override virtual {
        _burn(msg.sender, amount);
        WJK.burn(amount);
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