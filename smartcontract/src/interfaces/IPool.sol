// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed tokenIn);

    function initialize(address _tokenA, address _tokenB, address _factory) external;
    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity);
    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB);
    function swapExactTokensForTokens(address tokenIn, uint256 amountIn) external returns (uint256 amountOut);
    function getReserves() external view returns (uint256 reserveA, uint256 reserveB);
    function getTokens() external view returns (address tokenA, address tokenB);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
} 