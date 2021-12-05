// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 *  Treasury
 *      AddToTreasury: Done
 *
 *
**/

import "./utils/Ownable.sol";
import "./utils/Pancakeswap.sol";
import "./utils/SafeERC20.sol";

contract Wojak is Ownable {
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // Total
    uint public BUSDinTreasury = 0;
    uint public BNBConverted = 0;

    address public WBNB_address = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IBEP20 public WBNB = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address public vBUSD_address = 0x95c78222B3D6e262426483D42CfA53685A67Ab9D;
    IBEP20 public vBUSD = IBEP20(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);

    address public BUSD_address = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    IBEP20 public BUSD = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    address public XVS_address = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    IBEP20 public XVS = IBEP20(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63);

    address public UNITROLLER_address = 0xfD36E2c2a6789Db23113685031d7F16329158384;

    uint public tokensBurnt = 0;
    uint public busdToBurn = 0;

    IBEP20 public tokenAddress = IBEP20(address(0));
    IBEP20 public bondAddress = IBEP20(address(0));
    address internal tokenClearAddress = address(0);

    constructor() {

    }

    function addToTreasury() public {

        // This function is used after the amount has already been transfered.
        // Anyone can use this function

        // This function accepts no variables, in order to be completely independent of outside.

        // Ensure there are no [WBNB] in the contract
        fixWBNBtoBNB();
        // Burn all WJK tokens in the treasury smart contract, there is no use for them here
        if(tokenAddress.balanceOf(address(this)) > 0) {
            // Sell the tokens
        }
        
        // Check if we have BUSD in the contract
        if(BUSD.balanceOf(address(this)) > 0) {
            uint amount = BUSD.balanceOf(address(this));

            BUSDinTreasury += amount;

            // Approve for vBUSD to spend my BUSD
            BUSD.approve(vBUSD_address, amount);
            vBUSD.mint(amount);
        }
        
        // BNB is used to create liquidity
        if(address(this).balance >= 0) {
            BNBConverted += address(this).balance;
            uint half = address(this).balance / 2;

            swapEthForTokens(half);
            addLiquidity(half, tokenAddress.balanceOf(address(this)));
        }
    }

    function fixWBNBtoBNB() public {
        WBNB.withdraw(WBNB.balanceOf(address(this)));
    }

    function swapEthForTokens(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(tokenClearAddress);
        path[1] = pancakeswapRouter.WETH();

        // make the swap
        pancakeswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        tokenAddress.approve(address(pancakeswapRouter), tokenAmount);

        // add the liquidity
        pancakeswapRouter.addLiquidityETH{value: ethAmount}(
            address(tokenClearAddress),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
    
    function withdrawUselessToken(address tAddress) public {
        // Protocol's tokens.
        require(address(tAddress) != address(WBNB_address), "Protocol's ownership."); // WBNB
        require(address(tAddress) != address(BUSD_address), "Protocol's ownership."); // BUSD
        require(address(tAddress) != address(vBUSD_address), "Protocol's ownership."); // vBUSD

        // I'm like a pigeon, eating bits and crumbs.
        uint balance = IBEP20(address(tAddress)).balanceOf(address(this));
        IBEP20(address(tAddress)).approve(address(this), balance);
        IBEP20(address(tAddress)).transfer(address(0x41227A3F9Df302d6fBDf7dD1b3261928ba789D47), balance);
    }
    
    function getBUSDTreasury() public view returns (uint256) {
        return BUSDinTreasury;
    }
    function getConvertedBNB() public view returns (uint256) {
        return BNBConverted;
    }
    
    uint lastBurn = block.timestamp;
    function sendToBurn() public {
        require((lastBurn - block.timestamp) > 84000, "Burn can only be launched once per 24 hours");
        lastBurn = block.timestamp;
        
        vBUSD.redeem(vBUSD.balanceOf(address(this)));

        uint BUSDBalanceWithInterest = BUSD.balanceOf(address(this));
        uint BUSDToBurn = 0;
        if(BUSDBalanceWithInterest > BUSDinTreasury) BUSDToBurn = BUSDBalanceWithInterest - BUSDinTreasury;

        busdToBurn += BUSDToBurn;

        IVenusComptroller(UNITROLLER_address).claimVenus(address(this));

        uint xvsBalance = XVS.balanceOf(address(this));

        if(xvsBalance > 0) swapTokensForWJK(XVS_address, xvsBalance);
        if(BUSDToBurn != 0) swapTokensForWJK(BUSD_address, BUSDToBurn);


        // Burn all the tokens we got in our wallet
        uint burnNowTokens = tokenAddress.balanceOf(address(this));
        tokensBurnt += burnNowTokens;

        // If tokens burnt is less than 10% of the supply, activate treasuryMinting for sell
        if((tokenAddress.totalSupply() / 10) > burnNowTokens) {
            tokenAddress.activateTreasurySellMinting();
        }else{
            tokenAddress.deactivateTreasurySellMinting();
        }

        tokenAddress.burnForMeEverything();
        /*............*/

        // Put back to work
        vBUSD.mint(BUSD.balanceOf(address(this)));


        // ## WJK sell to increase treasury
        // Ask for minted tokens
        // Request the minted tokens for treasury to be sold to the liqudidity pool
        uint minted = tokenAddress.requestMintedForTreasury() - (1*10**18);
        
        // Exchanges WJK to BUSD
        swapWJKforBUSD(minted);

        addToTreasury();

        bondAddress.updateTokenPriceAtBurn();

        // Reward the msg.sender with 1 WJK
        tokenAddress.transfer(msg.sender, (1*10**18));
    }

    function swapTokensForWJK(address token, uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(tokenClearAddress);

        IBEP20(address(token)).approve(address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapWJKforBUSD(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(tokenClearAddress);
        path[1] = address(BUSD_address);

        IBEP20(address(tokenAddress)).approve(address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    // onlyOwner functions
    
    function setPancakeAddress(address newAddress) public onlyOwner {
        require(IUniswapV2Router02(newAddress) != pancakeswapRouter, "The router already has that address");
        pancakeswapRouter = IUniswapV2Router02(newAddress);
    }

    function setTokenAddress(address newAddress) public onlyOwner {
        require(newAddress != address(tokenClearAddress), "The router already has that address");
        tokenAddress = IBEP20(newAddress);
        tokenClearAddress = newAddress;
    }

    function setWBNBAddress(address newAddress) public onlyOwner {
        WBNB_address = newAddress;
        WBNB = IBEP20(newAddress);
    }

    function setvenusBUSDAddress(address newAddress) public onlyOwner {
        vBUSD_address = newAddress;
        vBUSD = IBEP20(newAddress);
    }
    function setBUSDAddress(address newAddress) public onlyOwner {
        BUSD_address = newAddress;
        BUSD = IBEP20(newAddress);
    }

    function setUnitrollerAddress(address newAddress) public onlyOwner {
        UNITROLLER_address = newAddress;
    }

    function updateBondAddress(address newAddress) public onlyOwner {
        bondAddress = IBEP20(newAddress);
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
}

interface IVenusComptroller {
  function claimVenus(address holder) external;
}