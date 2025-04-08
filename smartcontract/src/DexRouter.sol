// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";


contract DexRouter {
    using SafeERC20 for IERC20;
    
    address public immutable factory;
    address public immutable uniswapRouter;
    address public owner;
    uint256 public forwardingFee = 50; // 0.5% additional fee
    
    constructor(address _factory, address _uniswapRouter) {
        factory = _factory;
        uniswapRouter = _uniswapRouter;
        owner = msg.sender;
    }
    
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256) {
        // Try to get the pool from our factory
        address pool = IPoolFactory(factory).getPool(tokenIn, tokenOut);
        
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
        // Transfer tokens from sender to the pool
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(pool, amountIn);
        
        // Perform the swap
        uint256 amountOut = IPool(pool).swap(tokenIn, amountIn);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
        // Forward tokens to recipient
        IERC20(tokenOut).safeTransfer(recipient, amountOut);
        
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
        
        // Take the forwarding fee
        IERC20(tokenIn).safeTransferFrom(msg.sender, owner, feeAmount);
        
        // Transfer remaining tokens to this contract
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
            block.timestamp + 300 // 5 minute deadline
        );
        
        return amounts[1];
    }
    
    function setForwardingFee(uint256 _fee) external {
        require(msg.sender == owner, "Not owner");
        require(_fee <= 200, "Fee too high"); // Max 2%
        forwardingFee = _fee;
    }
    
    function setOwner(address _owner) external {
        require(msg.sender == owner, "Not owner");
        require(_owner != address(0), "Invalid address");
        owner = _owner;
    }
}