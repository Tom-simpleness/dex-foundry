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
} 