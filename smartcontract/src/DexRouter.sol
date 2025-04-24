// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IDexRouter.sol";

// --- Custom Errors ---
error DexRouterInvalidFactoryAddress();
error DexRouterInvalidUniswapRouterAddress();
error DexRouterInsufficientOutputAmount();
error DexRouterApproveFailed();
error DexRouterInvalidUniswapReturn();
error DexRouterNotFactoryOwner();
error DexRouterFeeTooHigh();


contract DexRouter is IDexRouter {
    using SafeERC20 for IERC20;
    
    address public immutable override factory;
    address public immutable override uniswapRouter;
    uint256 public override forwardingFee = 50; // 0.5% additional fee

    event ForwardingFeeUpdated(uint256 oldFee, uint256 newFee);
    
    constructor(address _factory, address _uniswapRouter) {
        if (_factory == address(0)) revert DexRouterInvalidFactoryAddress();
        if (_uniswapRouter == address(0)) revert DexRouterInvalidUniswapRouterAddress();
        factory = _factory;
        uniswapRouter = _uniswapRouter;
    }
    
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) external override returns (uint256 amountOut) {
        // Try to get the pool from our factory
        address pool = IPoolFactory(factory).tokenPairToPoolAddress(tokenIn, tokenOut);
        
        if (pool != address(0)) {
            // Pool exists in our DEX
            return _swapOnOurDex(tokenIn, pool, amountIn, minAmountOut, recipient);
        } else {
            // Pool doesn't exist, forward to Uniswap
            return _swapOnUniswap(tokenIn, tokenOut, amountIn, minAmountOut, recipient, deadline);
        }
    }
    
    function _swapOnOurDex(
        address tokenIn,
        address pool,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256) {
        // Transfer tokens DIRECTLY from sender (user) to the pool
        IERC20(tokenIn).safeTransferFrom(msg.sender, pool, amountIn);
        
        // Perform the swap - Pool will send tokenOut directly to recipient
        uint256 amountOut = IPool(pool).swap(tokenIn, amountIn, recipient);
        if (amountOut < minAmountOut) revert DexRouterInsufficientOutputAmount();
        
        return amountOut;
    }
    
    function _swapOnUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) internal returns (uint256) {
        uint256 feeAmount;
        uint256 amountAfterFee;
        // Calculate forwarding fee
        unchecked {
            feeAmount = (amountIn * forwardingFee) / 10000;
            amountAfterFee = amountIn - feeAmount;
        }
        
        // Get fee recipient from the factory
        address feeRecipient = IPoolFactory(factory).feeRecipient();

        // Take the forwarding fee and send to factory's fee recipient
        if (feeAmount > 0) { // Avoid transfer if fee is zero
           IERC20(tokenIn).safeTransferFrom(msg.sender, feeRecipient, feeAmount);
        }
        
        // Transfer remaining tokens to this contract (needed for Uniswap call)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountAfterFee);
        
        // Use standard approve and check its return value
        bool success = IERC20(tokenIn).approve(uniswapRouter, amountAfterFee);
        if (!success) revert DexRouterApproveFailed();
        
        // Define the path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        // Swap on Uniswap using the provided deadline
        uint[] memory amounts = IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amountAfterFee,
            minAmountOut,
            path,
            recipient,
            deadline
        );
        
        if (amounts.length < 2) revert DexRouterInvalidUniswapReturn();
        return amounts[amounts.length - 1]; // Return last amount (amountOut)
    }

    function setForwardingFee(uint256 _fee) external override {
        if (msg.sender != Ownable(factory).owner()) revert DexRouterNotFactoryOwner();
        if (_fee > 200) revert DexRouterFeeTooHigh(); // Max 2%
        uint256 oldFee = forwardingFee;
        forwardingFee = _fee;
        emit ForwardingFeeUpdated(oldFee, _fee);
    }
}