// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This is the upkeep contract, it ensures that everything in every contract is running smoothly, including launching timers
// This contract is executed at least once per block (15sec)

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Interfaces/IKeeper.sol";
import "./Interfaces/IPancakeswap.sol";

contract Keeper is KeeperCompatibleInterface, AccessControl {
    using SafeERC20 for IERC20;

    uint private constant INTERVAL = 28800; // Every 8 hours, Something happens, either Staking, Farming or SelfKeep
    uint private lastUpkeep = block.timestamp;
    uint public counter = 0;

    event LaunchedRewards(uint8 rewardsType);
    event SwapAndLiquify(uint256 wjk, uint256 busd);

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");    

    IERC20 public WJK = IERC20(address(0));
    IStaking public sWJK = IStaking(address(0));
    IChad public Chad = IChad(address(0));
    ITreasury public Treasury = ITreasury(address(0));
    ISoyFarms public SoyFarms = ISoyFarms(address(0));
    // Testnet
    IERC20 public constant BUSD = IERC20(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
    IERC20 public constant LINK = IERC20(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06);
    IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff);
    // Mainnet
    // IERC20 public constant BUSD = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    // IERC20 public constant LINK = IERC20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD);
    // IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override onlyRole(CONTRACT_ROLE) returns (bool upkeepNeeded, bytes memory /* performData */) {
        // Restrict the call to the UpKeeper contract only.
        // Once per hour
        upkeepNeeded = (block.timestamp - lastUpkeep) > INTERVAL && LINK.balanceOf(address(this)) > (1 * 10**18); // At least 1 LINK
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        return (upkeepNeeded, bytes(""));
    }
    
    uint public nextStaking = block.timestamp;
    uint public nextFarming = block.timestamp + 28800; // Delay by 8 hours
    uint public nextSelfKeep = block.timestamp + 57600; // Delay by 16 hours

    function performUpkeep(bytes calldata /* performData */) external override onlyRole(CONTRACT_ROLE) {
        lastUpkeep = block.timestamp;

        // For fun.
        counter = counter + 1;
        
        if(block.timestamp > nextStaking) {
            nextStaking += (INTERVAL * 3);
            
            sWJK.distributeRewards();
            Chad.updateTokenPriceAtStaking();

            Chad.increaseAvailable();

            emit LaunchedRewards(0);
            // 0 = Staking
        }

        if(block.timestamp > nextFarming) {
            nextFarming += (INTERVAL * 3);

            SoyFarms.distributeRewards();
            Chad.updateTokenPriceAtFarming();

            emit LaunchedRewards(1);
            // 1 = Farming
        }

        if(block.timestamp > nextSelfKeep) {
            nextSelfKeep += (INTERVAL * 3);

            uint busd = BUSD.balanceOf(address(this));

            // Contract receives BUSD from WJK transfer fees
            // Make sure the contract has enough LINK (at least 100 LINK, dunno why, just to make sure)
            if(LINK.balanceOf(address(this)) < (100 * 10**18)) {
                uint busdForLINK = 0;

                // If BUSD revenue is more than 100$
                if(busd > (100 * 10**18)) {
                    busdForLINK = 100 * 10**18;
                }else{ // If less, then we use everything to buy more LINK
                    busdForLINK = 100 * 10**18 - busd;
                }

                if(busdForLINK != 0) swap(address(BUSD), address(LINK), busdForLINK, address(this));
            }

            busd = BUSD.balanceOf(address(this));

            // If revenue more than 1000
            if(busd > (10 * 10**18)) {
                // Sent to use from 
                // cut the BUSD left in half
                uint halfBUSD = BUSD.balanceOf(address(this)) / 2;
                // 1 half for Liquidity
                swapAndLiquify(halfBUSD);
                // 1 half for Treasury
                BUSD.safeTransfer(address(Treasury), halfBUSD);

                // Make sure everything is added properly to the treasury.
                Treasury.addToTreasury();

                // Update bond price
                Chad.updateTokenPriceAtSelfKeep();

            }

            emit LaunchedRewards(2);
            // 2 = Self keep
        }

        // Future:
        //  * Rebase
        //  * Liquidations for loans
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WJK = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        sWJK = IStaking(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressChad(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Chad = IChad(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressTreasury(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Treasury = ITreasury(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressSoyFarm(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        SoyFarms = ISoyFarms(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function swapAndLiquify(uint256 busdAmount) private {
        uint256 halfBUSDAmount = busdAmount / 2;
        uint256 wjkAmount = swap(address(BUSD), address(WJK), halfBUSDAmount, address(Treasury)); 
        addLiquidity(halfBUSDAmount, wjkAmount);
        emit SwapAndLiquify(halfBUSDAmount, wjkAmount);
    }

    function swap(address token1, address token2, uint256 amount, address to) private returns (uint) {
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

    function addLiquidity(uint busdAmount, uint wjkAmount) private {
        IERC20(address(BUSD)).approve(address(pancakeswapRouter), busdAmount);
        IERC20(address(WJK)).approve(address(pancakeswapRouter), wjkAmount);

        pancakeswapRouter.addLiquidity(address(WJK), address(BUSD),0,0,0,0, address(Treasury), block.timestamp);
    }
}

interface IStaking {
    function distributeRewards() external;
}

interface IChad {
    function updateTokenPriceAtFarming() external;
    function updateTokenPriceAtSelfKeep() external;
    function updateTokenPriceAtStaking() external;
    function increaseAvailable() external;
}

interface ITreasury {
    function addToTreasury() external;
}

interface ISoyFarms {
    function distributeRewards() external;
}