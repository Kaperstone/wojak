// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Oven {
    /*
    uint public tokensBurnt = 0;
    uint public busdToBurn = 0;
    uint public usdcToBurn = 0;
    
    address public constant aBUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public constant aUSDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    function burnEverything() public {
        // Take BUSD
        // Add BUSD for WJK
        // Swap BUSD for WJK
        // Take USDC
        // Add USDC amount to [usdc]
        // Swap USDC for WJK
        // Add WJK balance to [tokensBurnt]
        // Burn WJK
    }

    function getTotalTokensBurnt() public view returns (uint256) {
        return tokensBurnt;
    }

    function getUSDC() public view returns (uint256) {
        return usdcToBurn;
    }
    
    function getBUSD() public view returns (uint256) {
        return busdToBurn;
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
    */
}