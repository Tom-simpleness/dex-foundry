// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Math {
    // Requirement: Prevent overflow and maintain precision in calculations
    // The sqrt function is needed for calculating optimal liquidity amounts
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    // Requirement: Calculate minimum of two values
    // Used for proportional liquidity calculations
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    // Requirement: Calculate price with minimal rounding errors
    // Used for calculating output amounts in swaps
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee) internal pure returns (uint256) {
        // Requirement: Ensure sufficient input amount
        require(amountIn > 0, "Math: INSUFFICIENT_INPUT_AMOUNT");
        // Requirement: Ensure pools have liquidity
        require(reserveIn > 0 && reserveOut > 0, "Math: INSUFFICIENT_LIQUIDITY");
        
        // Adjust for fee (fee is in basis points, e.g. 30 = 0.3%)
        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        
        return numerator / denominator;
    }
} 