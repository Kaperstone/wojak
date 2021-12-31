// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./contracts/token/ERC20/IERC20.sol";
import "./contracts/utils/Pancakeswap.sol";

contract Common is IERC20, IUniswapV2Router01 {
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    IERC20 public BUSD = IERC20(address(0));
    IERC20 public WBNB = IERC20(address(0));
    IERC20 public WJK = IERC20(address(0));
    IERC20 public sWJK = IERC20(address(0));

    // Pancakeswap v2
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(address(0));
    IUniswapV2Pair public pairAddress = IUniswapV2Pair(address(0));

    Wojak public wojak = Wojak(address(0));
    Staked public staked = Treasury(address(0));
    Bonds public chad = Bonds(address(0));
    GoldenRog public bridge = GoldenRog(address(0));
    Treasury public bunker = Treasury(address(0));
    Keeper public keeper = Keeper(address(0));
    Farm public farm = Farm(address(0));

    bool internal swapLock = false;

    function setAddress_BUSD() internal {}
    function setAddress_WBNB() internal {}
    function setAddress_WJK() internal {}
    function setAddress_SWJK() internal {}

    function swapAndLiquify(uint256 contractTokenBalance) internal {
        swapLock = true;
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half); 
        uint256 newBalance = address(this).balance - initialBalance;
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
        swapLock = false;
    }

    function swapTokensForTokens(address token1, address token2, uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        IERC20(address(WJK)).approve(address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            address(treasury), // Give the LP tokens to the treasury
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        IERC20(address(WJK)).approve(address(pancakeswapRouter), tokenAmount);

        pancakeswapRouter.addLiquidityETH{value: ethAmount}(
            address(WJK),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(bunker), // Give the LP tokens to the treasury
            block.timestamp
        );
    }

    function getWJKPrice(address pair, uint amount) public view returns(uint) {
        (uint Res0, uint Res1, ) = pair.getReserves();

        return ((amount * Res1) / Res0); // return amount of BUSD needed to buy WJK
    }
}