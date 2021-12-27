// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 * Balancer
 * Alpaca - Lever - Venus - Channels - Atlantis - EPS - Cream - Wowswap
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 *
 * Planned
 * ?????????
 * This is the strategy & bridge for investment
 * It calculates the different strategies and assigns a weight to them
 * They are all on ACS, the treasury will invest in the StableSwap to 
 * earn fees from those who use the strategy pool, when it switches
 * between different stable tokens, the treasury will benefit from it
 *
 *  USDT Venus, Atlantis, Channels, Bunny, Auto(Alpaca), Rabbit,
 *  USDC Venus, Atlantis, Bunny,
 *  BUSD Venus, Atlantis, Channels, Bunny, Auto(Alpaca), Rabbit,
 *  DAI  Venus, Bunny,
 *  TUSD Venus, Auto(Alpaca),
 *  BTC  Venus, Atlantis, Channels, Auto(Alpaca), Auto(Belt), Tranchess, Bunny, Rabbit,
 *  ETH  Venus, Atlantis, Channels, Auto(Alpaca), Auto(Belt), Tranchess, Rabbit,
 *  BNB  Venus, Atlantis, Channels, Auto(Alpaca), Auto(Belt), Rabbit,
 *  LINK Venus, Atlantis
 *
 * DeFi investment basket
 *  ACS, ACSI, CAKE, BSW, BUNNY, AUTO, ALPACA, CHESS, ATL, CHANNELS, MDX, BANANA, BABY, JAWS, RABBIT, BIFI
 *
 *
 * Stable LP (ACryptoS, Auto, Bunny)
 *  Pancake, MDEX, ApeSwap, Biswap
 *
**/
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/utils/SafeERC20.sol";
import "./@openzeppelin/contracts/utils/Pancakeswap.sol";

import "./iGoldenRog.sol";

contract GoldenRog is AccessControl {
    using SafeERC20 for IBEP20;

    IVenusComptroller public Unitroller = IVenusComptroller(address(0));
    IBEP20 public vBUSD = IBEP20(address(0));
    IBEP20 public BUSD = IBEP20(address(0));
    IBEP20 public XVS = IBEP20(address(0));

    uint BUSDinVenus = 0;

    constructor(bool testnet) {
        if(testnet) {
            vBUSD = IBEP20(address(0x08e0A5575De71037aE36AbfAfb516595fE68e5e4));
            BUSD = IBEP20(address(0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47));
            XVS = IBEP20(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
            Unitroller = IVenusComptroller(address(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D));
        }else{
            vBUSD = IBEP20(address(0x95c78222B3D6e262426483D42CfA53685A67Ab9D));
            BUSD = IBEP20(address(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7));
            XVS = IBEP20(address(0xcf6bb5389c92bdda8a3747ddb454cb7a64626c63));
            Unitroller = IVenusComptroller(address(0xfD36E2c2a6789Db23113685031d7F16329158384));
        }
    }

    function takeIncome() public {
        Unitroller.claimVenus(address(this));
        XVStoBUSD();

        uint exchangeRate = vBUSD.exchangeRateStored();
        uint BUSDStored = BUSDinVenus * exchangeRate;
        uint BUSDRevenue = BUSDStored - BUSDinVenus;

        // Get accurate revenue
        vBUSD.redeem(BUSDRevenue / exchangeRate);

        // Send all the BUSD we have to the treasury
        BUSD.safeTransfer(address(bunkerAddress), BUSD.balanceOf(address(this)));
    }

    function transformIncomeGeneratingTokensBackToTokens(address bunkerAddress) public {
        Unitroller.claimVenus(address(this));
        XVStoBUSD();

        // Take out all the BUSD from Venus
        vBUSD.redeem(vBUSD.balanceOf(address(this)));

        // Send all the BUSD we have to the treasury
        BUSD.safeTransfer(address(bunkerAddress), BUSD.balanceOf(address(this)));
    }
    
    function transformTokensToIncomeGeneratingTokens() public {
        vBUSD.mint(BUSD.balanceOf(address(this)));
    }

    function donateToTreasury() public {

    }

    function calculateRevenue() public view returns (uint256) {
        uint exchangeRate = vBUSD.exchangeRateStored();
        uint BUSDStored = BUSDinVenus * exchangeRate;
        uint BUSDRevenue = BUSDStored - BUSDinVenus;
        return BUSDRevenue;
    }

    function XVStoBUSD() private {
        // Exchange XVS to BUSD
        uint xvs_amount = XVS.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = address(XVS);
        path[1] = address(BUSD);

        XVS.safeApprove(address(pancakeswapRouter), xvs_amount);

        pancakeswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            xvs_amount,
            0, // accept any amount of ETH
            path,
            address(treasury),
            block.timestamp
        );
    }
}

interface IBEP20 {
    function balanceOf(address _owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function withdraw(uint wad) external;
    function burn(uint256 amount) external;
    function burnForMeEverything() external;
    function mint(uint mintAmount) external returns (uint256);
    function redeem(uint redeemTokens) external returns (uint256);
    function totalSupply() external returns (uint256);
    function requestMintedForTreasury() external returns (uint256);
    function activateTreasurySellMinting() external;
    function deactivateTreasurySellMinting() external;
    function updateTokenPriceAtBurn() external;
    function transformTokensToIncomeGeneratingTokens() external;
    function transformIncomeGeneratingTokensBackToTokens() external;
}

interface IVenusComptroller {
  function claimVenus(address holder) external;
}