// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 *  Treasury
 *      AddToTreasury: Done
 *
 *
**/

import "./Ownable.sol";
import "./Pancakeswap.sol";

contract Wojak is Ownable {
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // Total
    uint public TreasuryTotalValue = 0;
    uint public TreasuryTotalBNB = 0;

    // Alpaca `Lend`
    // uint public ALPACA = 0;
    uint public BNB = 0;
    address public constant ibBNB = 0xd7D069493685A581d27824Fc46EdA46B7EfC0063;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    uint public BUSD = 0;
    address public constant ibBUSD = 0x7C9e73d4C71dae564d41F78d56439bB4ba87592f;
    address public constant aBUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    // Venus `Lend`
    // uint public XVS = 0;
    uint public USDC = 0;
    address public constant vUSDC = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
    address public constant aUSDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    uint public tokensBurnt = 0;
    uint public busdToBurn = 0;
    uint public usdcToBurn = 0;

    address public pairAddress = address(0);
    address public tokenAddress = address(0);

    constructor() {
        
    }

    function addToTreasury() public {

        // This function is used after the amount has already been transfered.
        // Anyone can use this function

        // This function accepts no variables, in order to be completely independent of outside.

        // Ensure there are no [WBNB] in the contract
        fixWBNBtoBNB();
        // Burn all WJK tokens in the treasury smart contract, there is no use for them here
        if(IBEP20(address(tokenAddress)).balanceOf(address(this)) > 0) IBEP20(tokenAddress).burn(IBEP20(address(tokenAddress)).balanceOf(address(this)));
        
        // Check what tokens we have in the wallet
        // BUSD
        if(IBEP20(aBUSD).balanceOf(address(this)) > 0) {
            uint amount = IBEP20(aBUSD).balanceOf(address(this));

            BUSD += amount;
            TreasuryTotalValue += amount;

            IBEP20(ibBUSD).approve(address(ibBUSD), amount);
            IVault(ibBUSD).deposit(amount);
        }

        // USDC
        if(IBEP20(aUSDC).balanceOf(address(this)) > 0) {
            uint amount = IBEP20(aUSDC).balanceOf(address(this));

            USDC += amount;
            TreasuryTotalValue += amount;

            IBEP20(ibBUSD).approve(address(vUSDC), amount);
            VBep20(vUSDC).mint(amount);
        }
        
        // BNB is used to create liquidity
        if(address(this).balance >= 0) {
            uint half = address(this).balance / 2;
            TreasuryTotalBNB += address(this).balance;

            swapEthForTokens(half);
            addLiquidity(half, IBEP20(address(tokenAddress)).balanceOf(address(this)));
        }
    }

    function fixWBNBtoBNB() public {
        IBEP20(WBNB).withdraw(IBEP20(WBNB).balanceOf(address(this)));
    }

    function swapEthForTokens(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
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
        IBEP20(tokenAddress).approve(address(pancakeswapRouter), tokenAmount);

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

    function setPairAddress(address newAddress) public onlyOwner {
        require(newAddress != address(pairAddress), "The router already has that address");
        pairAddress = newAddress;
    }

    function setTokenAddress(address newAddress) public onlyOwner {
        require(newAddress != address(tokenAddress), "The router already has that address");
        tokenAddress = newAddress;
    }
    
    function withdrawUselessToken(address tAddress) public {
        // Protocol's tokens.
        require(address(tAddress) != address(aBUSD), "Protocol's ownership.");
        require(address(tAddress) != address(aUSDC), "Protocol's ownership.");
        require(address(tAddress) != address(WBNB), "Protocol's ownership.");
        require(address(tAddress) != address(this), "Protocol's ownership.");

        // I'm like a pigeon, eating bits and crumbs.
        uint balance = IBEP20(IBEP20(address(tokenAddress))).balanceOf(address(this));
        IBEP20(address(tokenAddress)).approve(address(this), balance);
        IBEP20(address(tokenAddress)).transfer(address(0x41227A3F9Df302d6fBDf7dD1b3261928ba789D47), balance);
    }
    
    function getTreasuryTotalStable() public view returns (uint256) {
        return TreasuryTotalValue;
    }
    function getTreasuryTotalBNB() public view returns (uint256) {
        return TreasuryTotalBNB;
    }
    
    uint lastBurn = block.timestamp;
    function sendToBurn() public {
        require((lastBurn - block.timestamp) > 84000, "Burn can only be launched once per 24 hours");
        
        // Alpaca BNB Vault withdraw
        IVault(address(ibBUSD)).withdraw(IBEP20(address(ibBUSD)).balanceOf(address(this)));
        VBep20(address(vUSDC)) .redeem(IBEP20(address(vUSDC)).balanceOf(address(this)));

        uint BUSDBalanceWithInterest = IBEP20(aBUSD).balanceOf(address(this));
        uint BUSDToBurn = 0;
        if(BUSDBalanceWithInterest > BUSD) {
            BUSDToBurn = BUSDBalanceWithInterest - BUSD;
            // swapExactTokensForTokens
        }

        uint USDCBalanceWithInterest = IBEP20(aUSDC).balanceOf(address(this));
        uint USDCToBurn = 0;
        if(USDCBalanceWithInterest > USDC) {
            USDCToBurn = USDCBalanceWithInterest - USDC;
            // swapExactTokensForTokens
        }

        busdToBurn += BUSDToBurn;
        usdcToBurn += USDCToBurn;


        if(USDCToBurn != 0) swapTokensForTokens(aUSDC, USDCToBurn);
        if(BUSDToBurn != 0) swapTokensForTokens(aBUSD, BUSDToBurn);

        // Burn all the tokens we got in our wallet
        tokensBurnt += IBEP20(tokenAddress).balanceOf(address(this));
        IBEP20(address(tokenAddress)).burnForMeEverything();

        // Alpaca vault 
        IVault(address(ibBNB)).deposit(address(this).balance);
        IVault(address(ibBUSD)).deposit(IBEP20(address(aBUSD)).balanceOf(address(this)));
        VBep20(address(vUSDC)).mint(IBEP20(address(aUSDC)).balanceOf(address(this)));
    }

    function swapTokensForTokens(address token, uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(this);

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
}

interface IBEP20 {
    function balanceOf(address _owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function withdraw(uint wad) external;
    function burn(uint256 amount) external;
    function burnForMeEverything() external;
}

interface IVault {
    function deposit(uint256 amount) external;
    function withdraw(uint share) external;
}

interface VBep20 {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
}