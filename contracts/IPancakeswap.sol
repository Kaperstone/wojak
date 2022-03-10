// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function addLiquidity(address,address,uint,uint,uint,uint,address,uint) external returns(uint,uint,uint);
    function swapExactTokensForTokens(uint,uint,address[] calldata,address,uint) external returns(uint[] memory);
    function swapTokensForExactTokens(uint,uint,address[] calldata,address,uint) external returns(uint[] memory);
    function getAmountsOut(uint, address[] memory) external view returns(uint[] memory);
}


interface IUniswapV2Pair {
    function getReserves() external view returns(uint112,uint112,uint32);
}

interface IUniswapV2Factory {
    function getPair(address, address) external view returns(address);
}