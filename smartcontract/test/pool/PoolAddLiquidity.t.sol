// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/mocks/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";

contract PoolAddLiquidityTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant FACTORY = address(4);
    
    Pool public pool;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    // Common liquidity values for testing
    uint256 constant AMOUNT1 = 100_000 * 10**18;
    uint256 constant AMOUNT2 = 200_000 * 10**18;
    
    function setUp() public {
        // Deploy token factory and create test tokens
        vm.startPrank(OWNER);
        tokenFactory = new TokenFactory();
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 1_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 1_000_000 * 10**18);
        
        // Deploy and initialize pool
        pool = new Pool();
        pool.initialize(token1, token2, FACTORY);
        
        // Transfer tokens to users for testing
        TestToken(token1).mint(USER1, 500_000 * 10**18);
        TestToken(token2).mint(USER1, 500_000 * 10**18);
        TestToken(token1).mint(USER2, 500_000 * 10**18);
        TestToken(token2).mint(USER2, 500_000 * 10**18);
        vm.stopPrank();
        
        // Approve tokens for pool
        vm.startPrank(USER1);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(USER2);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_addLiquidity_initialLiquidity() public {
        vm.startPrank(USER1);
        
        // Check initial state
        assertEq(pool.totalSupply(), 0, "Initial liquidity should be 0");
        
        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit IPool.LiquidityAdded(USER1, AMOUNT1, AMOUNT2, sqrt(AMOUNT1 * AMOUNT2) - 1000);
        
        // Add initial liquidity
        uint256 liquidity = pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // Verify liquidity tokens minted
        uint256 expectedLiquidity = sqrt(AMOUNT1 * AMOUNT2) - 1000; // Subtracting MINIMUM_LIQUIDITY
        assertEq(liquidity, expectedLiquidity, "Incorrect liquidity minted");
        
        // Dans l'implémentation, _totalSupply n'inclut pas MINIMUM_LIQUIDITY
        assertEq(pool.totalSupply(), expectedLiquidity, "Incorrect total supply");
        assertEq(pool.balanceOf(USER1), expectedLiquidity, "Incorrect user balance");
        assertEq(pool.balanceOf(address(0)), 1000, "Incorrect zero address balance"); // MINIMUM_LIQUIDITY locked
        
        // Verify reserves
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, AMOUNT1, "Incorrect reserve1");
        assertEq(reserve2, AMOUNT2, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    function test_addLiquidity_subsequentLiquidity() public {
        // First add initial liquidity
        vm.prank(USER1);
        pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // Check state before second addition
        uint256 totalSupplyBefore = pool.totalSupply();
        uint256 userBalanceBefore = pool.balanceOf(USER2);
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        
        // Add more liquidity with different user
        vm.startPrank(USER2);
        
        uint256 additionalAmount1 = AMOUNT1 / 2;
        uint256 additionalAmount2 = AMOUNT2 / 2;
        
        // Calculate expected liquidity
        uint256 expectedLiquidity = Math.min(
            (additionalAmount1 * totalSupplyBefore) / reserve1Before,
            (additionalAmount2 * totalSupplyBefore) / reserve2Before
        );
        
        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit IPool.LiquidityAdded(USER2, additionalAmount1, additionalAmount2, expectedLiquidity);
        
        // Add liquidity
        uint256 liquidity = pool.addLiquidity(additionalAmount1, additionalAmount2);
        
        // Verify liquidity tokens minted
        assertEq(liquidity, expectedLiquidity, "Incorrect liquidity minted");
        assertEq(pool.totalSupply(), totalSupplyBefore + expectedLiquidity, "Incorrect total supply");
        assertEq(pool.balanceOf(USER2), userBalanceBefore + expectedLiquidity, "Incorrect user balance");
        
        // Verify reserves
        (uint256 reserve1After, uint256 reserve2After) = pool.getReserves();
        assertEq(reserve1After, reserve1Before + additionalAmount1, "Incorrect reserve1");
        assertEq(reserve2After, reserve2Before + additionalAmount2, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    function test_addLiquidity_revertsWhenZeroAmounts() public {
        vm.startPrank(USER1);
        
        // Zero amount A
        vm.expectRevert("Pool: insufficient deposit amounts");
        pool.addLiquidity(0, AMOUNT2);
        
        // Zero amount B
        vm.expectRevert("Pool: insufficient deposit amounts");
        pool.addLiquidity(AMOUNT1, 0);
        
        // Both zero
        vm.expectRevert("Pool: insufficient deposit amounts");
        pool.addLiquidity(0, 0);
        
        vm.stopPrank();
    }
    
    function test_addLiquidity_revertsWhenInsufficientLiquidityMinted() public {
        // First add initial liquidity with large amounts
        vm.prank(USER1);
        pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // Mint additional tokens for USER2
        vm.startPrank(OWNER);
        TestToken(token1).mint(USER2, 10); // Only mint a tiny amount
        TestToken(token2).mint(USER2, 10); // Only mint a tiny amount
        vm.stopPrank();
        
        // USER2 approves tiny amounts
        vm.startPrank(USER2);
        TestToken(token1).approve(address(pool), 10);
        TestToken(token2).approve(address(pool), 10);
        
        // Try to add tiny amounts that would result in 0 liquidity tokens
        vm.expectRevert("Pool: insufficient liquidity minted");
        pool.addLiquidity(1, 1);
        vm.stopPrank();
    }
    
    function test_addLiquidity_multipleUsers() public {
        // User1 adds liquidity
        vm.prank(USER1);
        uint256 liquidity1 = pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // User2 adds liquidity
        vm.prank(USER2);
        uint256 liquidity2 = pool.addLiquidity(AMOUNT1 * 2, AMOUNT2 * 2);
        
        // Verify balances
        assertEq(pool.balanceOf(USER1), liquidity1, "Incorrect USER1 balance");
        assertEq(pool.balanceOf(USER2), liquidity2, "Incorrect USER2 balance");
        
        // Dans l'implémentation, _totalSupply n'inclut pas MINIMUM_LIQUIDITY
        assertEq(pool.totalSupply(), liquidity1 + liquidity2, "Incorrect total supply");
        
        // Verify reserves (USER1 + USER2 contributions)
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, AMOUNT1 + AMOUNT1 * 2, "Incorrect reserve1");
        assertEq(reserve2, AMOUNT2 + AMOUNT2 * 2, "Incorrect reserve2");
    }
    
    function test_addLiquidity_multipleTimes() public {
        vm.startPrank(USER1);
        
        // First addition
        uint256 liquidity1 = pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // Second addition
        uint256 liquidity2 = pool.addLiquidity(AMOUNT1 / 2, AMOUNT2 / 2);
        
        // Third addition
        uint256 liquidity3 = pool.addLiquidity(AMOUNT1 / 4, AMOUNT2 / 4);
        
        // Verify cumulative balance
        assertEq(pool.balanceOf(USER1), liquidity1 + liquidity2 + liquidity3, "Incorrect total user balance");
        
        // Verify reserves (all contributions)
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, AMOUNT1 + AMOUNT1 / 2 + AMOUNT1 / 4, "Incorrect reserve1");
        assertEq(reserve2, AMOUNT2 + AMOUNT2 / 2 + AMOUNT2 / 4, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    function test_fuzz_addLiquidity(uint128 amount1, uint128 amount2) public {
        // Ensure amounts are reasonable (not too small, not too large)
        vm.assume(amount1 > 1000 && amount2 > 1000);
        vm.assume(amount1 < 10_000_000 * 10**18 && amount2 < 10_000_000 * 10**18);
        
        // Mint tokens for fuzz test
        vm.startPrank(OWNER);
        TestToken(token1).mint(USER1, amount1);
        TestToken(token2).mint(USER1, amount2);
        vm.stopPrank();
        
        // Add liquidity
        vm.startPrank(USER1);
        uint256 liquidityMinted = pool.addLiquidity(amount1, amount2);
        
        // Initial liquidity calculation
        uint256 expectedLiquidity = sqrt(uint256(amount1) * uint256(amount2)) - 1000;
        
        // Verify results
        assertEq(liquidityMinted, expectedLiquidity, "Incorrect liquidity minted");
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, amount1, "Incorrect reserve1");
        assertEq(reserve2, amount2, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    // Helper function to calculate square root (same as in Math library)
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
} 