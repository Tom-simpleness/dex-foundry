// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {stdMath} from "forge-std/StdMath.sol";
import "../../src/Pool.sol";
import "../../src/mocks/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";
import "../../src/lib/Math.sol"; // Import Math for sqrt AND min

contract PoolAddLiquidityTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant FACTORY = address(4);
    
    Pool public pool;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    // Common test values
    uint256 constant AMOUNT1 = 100_000 * 10**18; // 100K
    uint256 constant AMOUNT2 = 200_000 * 10**18; // 200K
    
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
        
        // Calculate expected liquidity without MINIMUM_LIQUIDITY
        uint256 expectedLiquidity = Math.sqrt(AMOUNT1 * AMOUNT2);
        
        // Expect event emission with the corrected liquidity value
        vm.expectEmit(true, true, true, true);
        emit IPool.LiquidityAdded(USER1, AMOUNT1, AMOUNT2, expectedLiquidity);
        
        // Add initial liquidity
        uint256 actualLiquidity = pool.addLiquidity(AMOUNT1, AMOUNT2);
        
        // Verify liquidity minted
        assertEq(actualLiquidity, expectedLiquidity, "Incorrect initial liquidity minted");
        
        // Verify total supply and user balance
        assertEq(pool.totalSupply(), expectedLiquidity, "Incorrect total supply after initial mint");
        assertEq(pool.balanceOf(USER1), expectedLiquidity, "Incorrect user LP balance after initial mint");
        // Check that address(0) does NOT have MINIMUM_LIQUIDITY
        assertEq(pool.balanceOf(address(0)), 0, "address(0) should not have LP tokens");
        
        // Verify reserves match amounts added
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, AMOUNT1, "Incorrect reserve1 after initial add");
        assertEq(reserve2, AMOUNT2, "Incorrect reserve2 after initial add");
        
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
        
        // Verify total supply
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
    
    function test_fuzz_addLiquidity(uint128 amountA, uint128 amountB) public {
        vm.assume(amountA > 0 && amountB > 0);
        
        // Mint necessary tokens to USER1 for the fuzz amounts
        vm.startPrank(OWNER);
        TestToken(token1).mint(USER1, amountA);
        TestToken(token2).mint(USER1, amountB);
        vm.stopPrank();
        
        vm.startPrank(USER1);
        
        // Get state before adding liquidity
        uint256 totalSupplyBefore = pool.totalSupply();
        (uint256 reserveABefore, uint256 reserveBBefore) = pool.getReserves();
        uint256 userLpBefore = pool.balanceOf(USER1);
        
        // Calculate expected liquidity
        uint256 expectedLiquidity;
        if (totalSupplyBefore == 0) {
            expectedLiquidity = Math.sqrt(uint256(amountA) * uint256(amountB)); // Use new formula
        } else {
            uint256 liquidityA = (uint256(amountA) * totalSupplyBefore) / reserveABefore;
            uint256 liquidityB = (uint256(amountB) * totalSupplyBefore) / reserveBBefore;
            expectedLiquidity = Math.min(liquidityA, liquidityB);
        }

        // Perform addLiquidity
        uint256 actualLiquidity = pool.addLiquidity(amountA, amountB);
        
        // Verify minted liquidity amount
        assertEq(actualLiquidity, expectedLiquidity, "Incorrect liquidity minted");
        
        // Verify state after
        assertEq(pool.totalSupply(), totalSupplyBefore + actualLiquidity, "Total supply mismatch");
        assertEq(pool.balanceOf(USER1), userLpBefore + actualLiquidity, "User LP balance mismatch");
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveAAfter, reserveABefore + amountA, "Reserve A mismatch");
        assertEq(reserveBAfter, reserveBBefore + amountB, "Reserve B mismatch");

        vm.stopPrank();
    }
} 