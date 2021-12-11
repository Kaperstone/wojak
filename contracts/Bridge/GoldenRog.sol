// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./iGoldenRog.sol";

contract GoldenRog {
    address public UNITROLLER_address = address(0);
    IBEP20 public vBUSD = IBEP20(address(0));
    IBEP20 public BUSD = IBEP20(address(0));

    constructor(bool testnet) {
        if(testnet) {
            vBUSD = IBEP20(address(0x08e0A5575De71037aE36AbfAfb516595fE68e5e4));
            BUSD = IBEP20(address(0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47));
            UNITROLLER_address = address(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D);
        }else{
            vBUSD = IBEP20(address(0x95c78222B3D6e262426483D42CfA53685A67Ab9D));
            BUSD = IBEP20(address(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7));
            UNITROLLER_address = address(0xfD36E2c2a6789Db23113685031d7F16329158384);
        }
    }

    function getIncome() public {
        IVenusComptroller(UNITROLLER_address).claimVenus(address(this));
        vBUSD.redeem(vBUSD.balanceOf(address(this)));

        vBUSD.mint(BUSD.balanceOf(address(this)));
    }

    function transformIncomeGeneratingTokensBackToTokens() public {
        IVenusComptroller(UNITROLLER_address).claimVenus(address(this));
        vBUSD.redeem(vBUSD.balanceOf(address(this)));


    }
    
    function transformTokensToIncomeGeneratingTokens() public {
        vBUSD.mint(BUSD.balanceOf(address(this)));
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