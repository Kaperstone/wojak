// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Oven {
    /*
    bool public burnLock = false;
    uint public tokensBurnt = 0;
    uint public lastBurningTimestamp = 0;
    
    uint256 public lastBurnTimestamp = 0;

    function startBurnEvent() public oncePer(86400, "Burning event can only be launched once per 24 hours") {
        burnLock = true;
        // Get the treasury out

        // Alpaca BNB Vault withdraw
        IVault(address(ibBNB)) .withdraw(IBEP20(address(ibBNB)).balanceOf(address(this)));
        IVault(address(ibBUSD)).withdraw(IBEP20(address(ibBUSD)).balanceOf(address(this)));
        VBep20(address(vUSDC)) .redeem(IBEP20(address(vUSDC)).balanceOf(address(this)));

        uint BUSDBalanceWithInterest = IBEP20(aBUSD).balanceOf(this);
        uint BUSDToBurn = 0;
        if(BUSDBalanceWithInterest > BUSD) {
            BUSDToBurn = BUSDBalanceWithInterest - BUSD;
            // swapExactTokensForTokens
        }

        uint USDCBalanceWithInterest = IBEP20(aUSDC).balanceOf(this);
        uint USDCToBurn = 0;
        if(USDCBalanceWithInterest > USDC) {
            USDCToBurn = USDCBalanceWithInterest - USDC;
            // swapExactTokensForTokens
        }

        uint BNBBalanceWithInterest = address(this).balance;
        uint BNBToBurn = 0;
        if(BNBBalanceWithInterest > BNB) {
            BNBToBurn = BNBBalanceWithInterest - BNB;
            // swapExactETHForTokens
        }

        if(BNBToBurn  != 0) swapEthForTokens(BNBToBurn);
        if(USDCToBurn != 0) swapTokensForTokens(aUSDC, USDCToBurn);
        if(BUSDToBurn != 0) swapTokensForTokens(aBUSD, BUSDToBurn);

        // Burn all the tokens we got in our wallet
        tokensBurnt += balanceOf(address(this));
        _burn(address(this), balanceOf(address(this)));

        // Alpaca vault 
        IVault(address(ibBNB)).deposit(address(this).balance);
        IVault(address(ibBUSD)).deposit(IBEP20(address(aBUSD)).balanceOf(address(this)));
        VBep20(address(vUSDC)).mint(IBEP20(address(aUSDC)).balanceOf(address(this)));
        checkSmartContractForLeftovers();
        burnLock = false;
    }

    function getTotalTokensBurnt() public view returns (uint256) {
        return tokensBurnt;
    }

    function getLastBurnEventTimestamp() public view returns (uint256) {
        return lastBurningTimestamp;
    }

    function swapTokensForTokens(address token, uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(this);

        _approve(address(token), address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function swapEthForTokens(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeswapRouter.WETH();
        path[1] = address(this);

        _approve(address(this), address(pancakeswapRouter), tokenAmount);

        // make the swap
        pancakeswapRouter.swapExactEthForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    
    modifier oncePer(uint time, string memory errorMessage) {
        require((lastBurningTimestamp - block.timestamp) > time, errorMessage);
        lastBurningTimestamp = block.timestamp;
        _;
    }

    function strcmp(string memory a, string memory b) pure public returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }*/
}