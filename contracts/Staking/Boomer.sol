// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Common.sol";

abstract contract Boomer is Common, ERC20 {
    using SafeERC20 for IERC20;

    event Stake(uint wjkAmount);
    event Unstake(uint boomerAmount);
    event RewardsDistributed(uint rewards);
    event TreasuryFill(uint busd);
    event Burn(uint wjkAmount, uint boomerAmount);


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
    uint private lastStakingRewards = 0;

    constructor() ERC20("Boomer Staking", "BOOMER") Common() {}

    // ---------- STAKES ----------

    function stake(uint wjkAmount) public returns (uint256) {
        // We transfer his tokens to the smart contract, its now in its posession
        WJK.safeTransferFrom(msg.sender, address(this), wjkAmount);
        
        uint boomerAmount = wojakTokenValue(wjkAmount);
        wjkBalance += wjkAmount;

        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, boomerAmount); // Mint Boomer tokens to his account

        stakeLock[msg.sender] = block.timestamp + 86400;

        emit Stake(wjkAmount);

        return boomerAmount;
    }

    function unstake(uint bAmount) public returns(uint256) {
        require(block.timestamp > stakeLock[msg.sender], "!24hr");
        // He requests back more than he can
        require(bAmount >= balanceOf(msg.sender), "No tokens to unstake");

        // We burn his Boomers
        uint wjkToSend = stakerBalance(msg.sender);
        wjkBalance -= wjkToSend;
        // We don't need his BOOMER tokens
        _burn(msg.sender, bAmount);

        // Give him his tokens from this contract
        WJK.safeTransfer(msg.sender, wjkToSend);

        emit Unstake(bAmount);

        return wjkToSend;
    }

    // ---------- FINDERS ----------

    // For use to find underlying WJK amount
    function stakerBalance(address _stakeholder) public view returns (uint256) {
        // New model is to give 0.125% of what he is holding
        return balanceOf(_stakeholder) * (totalSupply() / wjkBalance);
        // It is also auto-compounding :)
    }

    // Can be used as `Index` and to find the worth of X amount of tokens
    function stakedTokenValue(uint amount) public view returns (uint256) {
        // sWJK * index
        return amount * (totalSupply() / wjkBalance);
    }

    function wojakTokenValue(uint amount) public view returns (uint256) {
        // WJK / index
        return amount / (totalSupply() / wjkBalance);
    }

    // ---------- REWARDS ----------

    // Distribute once per 24 hours
    function distributeRewards() public onlyRole(KEEPER_ROLE) {
        require((lastStakingRewardsTimestamp - block.timestamp) > 21600, "!6hr");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 21600;

        uint lTotalRewards = wjkBalance / 800; // We just raise the amount of wjk contract holds

        // Mint to the contract
        wojak.mint(address(this), lTotalRewards);

        // For statistics
        totalRewards += lTotalRewards;
        lastStakingRewards = lTotalRewards;

        emit RewardsDistributed(lTotalRewards);
        
        // We help the treasury grow a little bit
        if(fillAmount > 0) {
            // Mint some tokens to fill the treasury
            wojak.mint(address(this), fillAmount);

            // Sell half to get BUSD
            uint busdToFill = swap(address(WJK), address(BUSD), fillAmount, address(keeper));
            busdCollectedForTreasury += busdToFill;
            emit TreasuryFill(busdToFill);
        }
    }

    function setFillAmount(uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fillAmount = amount * 10**18;
    }

    function lastMinted() public view returns(uint256) {
        return lastStakingRewards;
    }

    function burn(uint sWJKAmount) public {
        // Burn in this contract the underlying WJK of his sWJK tokens
        uint wjkAmount = stakerBalance(msg.sender);
        wojak.burn(wjkAmount);
        // Regularly burn his sWJK tokens
        _burn(msg.sender, sWJKAmount);

        emit Burn(wjkAmount, sWJKAmount);
    }
}