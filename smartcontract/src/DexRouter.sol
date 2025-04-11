// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";


contract DexRouter {
    using SafeERC20 for IERC20;
    
    address public immutable factory;
    address public immutable uniswapRouter;
    uint256 public forwardingFee = 50; // 0.5% additional fee
    
    constructor(address _factory, address _uniswapRouter) {
        require(_factory != address(0), "DexRouter: Invalid factory address");
        require(_uniswapRouter != address(0), "DexRouter: Invalid uniswapRouter address");
        factory = _factory;
        uniswapRouter = _uniswapRouter;
    }
    
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256) {
        // Try to get the pool from our factory
        address pool = IPoolFactory(factory).tokenPairToPoolAddress(tokenIn, tokenOut);
        
        if (pool != address(0)) {
            // Pool exists in our DEX
            return _swapOnOurDex(tokenIn, tokenOut, pool, amountIn, minAmountOut, recipient);
        } else {
            // Pool doesn't exist, forward to Uniswap
            return _swapOnUniswap(tokenIn, tokenOut, amountIn, minAmountOut, recipient);
        }
    }
    
    function _swapOnOurDex(
        address tokenIn,
        address tokenOut,
        address pool,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256) {
        // Transfer tokens DIRECTLY from sender (user) to the pool
        IERC20(tokenIn).safeTransferFrom(msg.sender, pool, amountIn);
        
        // Perform the swap - Pool will send tokenOut directly to recipient
        uint256 amountOut = IPool(pool).swap(tokenIn, amountIn, recipient);
        require(amountOut >= minAmountOut, "DexRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        return amountOut;
    }
    
    function _swapOnUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256) {
        // Calculate forwarding fee
        uint256 feeAmount = (amountIn * forwardingFee) / 10000;
        uint256 amountAfterFee = amountIn - feeAmount;
        
        // Get fee recipient from the factory
        address feeRecipient = IPoolFactory(factory).feeRecipient();

        // Take the forwarding fee and send to factory's fee recipient
        if (feeAmount > 0) { // Avoid transfer if fee is zero
           IERC20(tokenIn).safeTransferFrom(msg.sender, feeRecipient, feeAmount);
        }
        
        // Transfer remaining tokens to this contract (needed for Uniswap call)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountAfterFee);
        IERC20(tokenIn).approve(uniswapRouter, amountAfterFee);
        
        // Define the path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        // Swap on Uniswap
        uint[] memory amounts = IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amountAfterFee,
            minAmountOut,
            path,
            recipient,
            block.timestamp // Use current block timestamp for deadline check (consider adding buffer?)
        );
        
        require(amounts.length >= 2, "DexRouter: Invalid Uniswap return");
        return amounts[amounts.length - 1]; // Return last amount (amountOut)
    }
    
    function setForwardingFee(uint256 _fee) external {
        require(msg.sender == Ownable(factory).owner(), "DexRouter: Not factory owner");
        require(_fee <= 200, "DexRouter: Fee too high"); // Max 2%
        forwardingFee = _fee;
    }
}