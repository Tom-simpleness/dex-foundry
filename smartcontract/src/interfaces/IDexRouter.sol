// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IDexRouter {
    // External view functions
    function factory() external view returns (address);
    function uniswapRouter() external view returns (address);
    function forwardingFee() external view returns (uint256);

    // External state-changing functions
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256 amountOut);

    function setForwardingFee(uint256 _fee) external;
} 