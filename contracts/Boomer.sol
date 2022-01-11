// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Interfaces/IBoomer.sol";
import "./Interfaces/IPancakeswap.sol";

contract Boomer is ERC20, AccessControl {

    event Stake(uint wjkAmount);
    event Unstake(uint boomerAmount);
    event RewardsDistributed(uint rewards);
    event TreasuryFill(uint busd);
    event Burn(uint wjkAmount, uint boomerAmount);

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    IWojak public WJK = IWojak(address(0));
    address public keeper = address(0);
    address public constant BUSD = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee;
    IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
    // address public constant BUSD = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;
    // IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));

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

    constructor() ERC20("Boomer Staking", "BOOMER") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    // ---------- STAKES ----------

    function stake(uint wjkAmount) public returns (uint256) {
        // We transfer his tokens to the smart contract, its now in its posession
        WJK.transferFrom(msg.sender, address(this), wjkAmount);
        
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
        WJK.transfer(msg.sender, wjkToSend);

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
    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        require((lastStakingRewardsTimestamp - block.timestamp) > 21600, "!6hr");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 21600;

        uint lTotalRewards = wjkBalance / 800; // We just raise the amount of wjk contract holds

        // Mint to the contract
        WJK.mint(address(this), lTotalRewards);

        // For statistics
        totalRewards += lTotalRewards;
        lastStakingRewards = lTotalRewards;

        emit RewardsDistributed(lTotalRewards);
        
        // We help the treasury grow a little bit
        if(fillAmount > 0) {
            // Mint some tokens to fill the treasury
            WJK.mint(address(this), fillAmount);

            // Sell half to get BUSD
            uint busdToFill = swap(address(WJK), BUSD, fillAmount, keeper);
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
        WJK.burn(wjkAmount);
        // Regularly burn his sWJK tokens
        _burn(msg.sender, sWJKAmount);

        emit Burn(wjkAmount, sWJKAmount);
    }

    function swap(address token1, address token2, uint256 amount, address to) internal returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(token1);  
        path[1] = address(token2);

        IERC20(address(token1)).approve(address(pancakeswapRouter), amount);

        uint[] memory amounts = pancakeswapRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of tokens back
            path,
            to, // Give the LP tokens to the treasury
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }
    
    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WJK = IWojak(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
        grantRole(CONTRACT_ROLE, newAddress);
    }
}

interface IWojak is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint amount) external;
}