// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/mocks/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";

contract PoolRemoveLiquidityTest is Test {
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
    uint256 public liquidityAdded;
    
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
        
        // Add initial liquidity for testing removals
        liquidityAdded = pool.addLiquidity(AMOUNT1, AMOUNT2);
        vm.stopPrank();
        
        vm.startPrank(USER2);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_removeLiquidity_full() public {
        vm.startPrank(USER1);
        
        // Get balances before removal
        uint256 token1BalanceBefore = TestToken(token1).balanceOf(USER1);
        uint256 token2BalanceBefore = TestToken(token2).balanceOf(USER1);
        uint256 lpTokensBefore = pool.balanceOf(USER1);
        
        // Get reserves before removal
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        
        // Expected amounts to receive
        uint256 expectedAmount1 = (liquidityAdded * reserve1Before) / pool.totalSupply();
        uint256 expectedAmount2 = (liquidityAdded * reserve2Before) / pool.totalSupply();
        
        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit IPool.LiquidityRemoved(USER1, expectedAmount1, expectedAmount2, liquidityAdded);
        
        // Remove all liquidity
        (uint256 amount1, uint256 amount2) = pool.removeLiquidity(liquidityAdded);
        
        // Verify tokens received
        assertEq(amount1, expectedAmount1, "Incorrect amount1 received");
        assertEq(amount2, expectedAmount2, "Incorrect amount2 received");
        
        // Verify balances
        assertEq(TestToken(token1).balanceOf(USER1), token1BalanceBefore + expectedAmount1, "Incorrect token1 balance");
        assertEq(TestToken(token2).balanceOf(USER1), token2BalanceBefore + expectedAmount2, "Incorrect token2 balance");
        assertEq(pool.balanceOf(USER1), lpTokensBefore - liquidityAdded, "Incorrect LP token balance");
        
        // Verify reserves (should be 0 except for potential dust)
        (uint256 reserve1After, uint256 reserve2After) = pool.getReserves();
        assertEq(reserve1After, reserve1Before - expectedAmount1, "Incorrect reserve1");
        assertEq(reserve2After, reserve2Before - expectedAmount2, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_partial() public {
        vm.startPrank(USER1);
        
        // Remove only half of the liquidity
        uint256 liquidityToRemove = liquidityAdded / 2;
        
        // Get balances before removal
        uint256 token1BalanceBefore = TestToken(token1).balanceOf(USER1);
        uint256 token2BalanceBefore = TestToken(token2).balanceOf(USER1);
        uint256 lpTokensBefore = pool.balanceOf(USER1);
        
        // Get reserves before removal
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        
        // Expected amounts to receive
        uint256 expectedAmount1 = (liquidityToRemove * reserve1Before) / pool.totalSupply();
        uint256 expectedAmount2 = (liquidityToRemove * reserve2Before) / pool.totalSupply();
        
        // Remove partial liquidity
        (uint256 amount1, uint256 amount2) = pool.removeLiquidity(liquidityToRemove);
        
        // Verify tokens received
        assertEq(amount1, expectedAmount1, "Incorrect amount1 received");
        assertEq(amount2, expectedAmount2, "Incorrect amount2 received");
        
        // Verify balances
        assertEq(TestToken(token1).balanceOf(USER1), token1BalanceBefore + expectedAmount1, "Incorrect token1 balance");
        assertEq(TestToken(token2).balanceOf(USER1), token2BalanceBefore + expectedAmount2, "Incorrect token2 balance");
        assertEq(pool.balanceOf(USER1), lpTokensBefore - liquidityToRemove, "Incorrect LP token balance");
        
        // Verify reserves (should be reduced proportionally)
        (uint256 reserve1After, uint256 reserve2After) = pool.getReserves();
        assertEq(reserve1After, reserve1Before - expectedAmount1, "Incorrect reserve1");
        assertEq(reserve2After, reserve2Before - expectedAmount2, "Incorrect reserve2");
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_multipleUsers() public {
        // User2 adds some liquidity first
        vm.startPrank(USER2);
        uint256 user2Liquidity = pool.addLiquidity(AMOUNT1, AMOUNT2);
        vm.stopPrank();
        
        // Get initial states
        uint256 totalSupplyBefore = pool.totalSupply();
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        
        // User1 removes half their liquidity
        vm.startPrank(USER1);
        uint256 user1RemoveAmount = liquidityAdded / 2;
        (uint256 user1Amount1, uint256 user1Amount2) = pool.removeLiquidity(user1RemoveAmount);
        vm.stopPrank();
        
        // User2 removes all their liquidity
        vm.startPrank(USER2);
        (uint256 user2Amount1, uint256 user2Amount2) = pool.removeLiquidity(user2Liquidity);
        vm.stopPrank();
        
        // Verify final states
        uint256 expectedTotalSupply = totalSupplyBefore - user1RemoveAmount - user2Liquidity;
        assertEq(pool.totalSupply(), expectedTotalSupply, "Incorrect final total supply");
        
        // Verify each user got the correct proportion of tokens
        uint256 expectedUser1Amount1 = (user1RemoveAmount * reserve1Before) / totalSupplyBefore;
        uint256 expectedUser1Amount2 = (user1RemoveAmount * reserve2Before) / totalSupplyBefore;
        uint256 expectedUser2Amount1 = (user2Liquidity * (reserve1Before - expectedUser1Amount1)) / (totalSupplyBefore - user1RemoveAmount);
        uint256 expectedUser2Amount2 = (user2Liquidity * (reserve2Before - expectedUser1Amount2)) / (totalSupplyBefore - user1RemoveAmount);
        
        assertApproxEqRel(user1Amount1, expectedUser1Amount1, 1e16, "User1 amount1 incorrect"); // 0.1% tolerance
        assertApproxEqRel(user1Amount2, expectedUser1Amount2, 1e16, "User1 amount2 incorrect");
        assertApproxEqRel(user2Amount1, expectedUser2Amount1, 1e16, "User2 amount1 incorrect");
        assertApproxEqRel(user2Amount2, expectedUser2Amount2, 1e16, "User2 amount2 incorrect");
    }
    
    function test_removeLiquidity_revertsWhenZero() public {
        vm.startPrank(USER1);
        
        // Try to remove 0 liquidity
        vm.expectRevert("Pool: insufficient liquidity burned");
        pool.removeLiquidity(0);
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_revertsWhenInsufficientBalance() public {
        vm.startPrank(USER1);
        
        // Try to remove more liquidity than owned
        vm.expectRevert();
        pool.removeLiquidity(liquidityAdded + 1);
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_revertsWhenInsufficientAmounts() public {
        // Add tiny amount of liquidity to create a situation where removal would result in zero token amounts
        vm.startPrank(USER2);
        pool.addLiquidity(1_000_000, 1_000_000); // Very small amounts compared to USER1's liquidity
        
        // Try to remove tiny amount of liquidity that would result in 0 token amounts
        uint256 tinyLiquidity = 1;
        vm.expectRevert("Pool: insufficient amounts");
        pool.removeLiquidity(tinyLiquidity);
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_multipleTimes() public {
        vm.startPrank(USER1);
        
        uint256 remainingLiquidity = liquidityAdded;
        uint256 removalStep = liquidityAdded / 4;
        
        for (uint i = 0; i < 4; i++) {
            // Get state before removal
            (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
            uint256 totalSupplyBefore = pool.totalSupply();
            
            // Remove portion of liquidity
            (uint256 amount1, uint256 amount2) = pool.removeLiquidity(removalStep);
            
            // Verify amounts match expected proportions
            uint256 expectedAmount1 = (removalStep * reserve1Before) / totalSupplyBefore;
            uint256 expectedAmount2 = (removalStep * reserve2Before) / totalSupplyBefore;
            
            assertEq(amount1, expectedAmount1, "Incorrect amount1 in step");
            assertEq(amount2, expectedAmount2, "Incorrect amount2 in step");
            
            remainingLiquidity -= removalStep;
        }
        
        // Verify all liquidity has been removed
        assertEq(pool.balanceOf(USER1), 0, "User should have no LP tokens left");
        
        vm.stopPrank();
    }
    
    function test_fuzz_removeLiquidity(uint8 percentToRemove) public {
        vm.assume(percentToRemove > 0 && percentToRemove <= 100);
        
        vm.startPrank(USER1);
        
        // Calculate portion to remove (1-100%)
        uint256 liquidityToRemove = (liquidityAdded * percentToRemove) / 100;
        
        // Ensure we're removing something
        vm.assume(liquidityToRemove > 0);
        
        // Get state before removal
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        uint256 totalSupplyBefore = pool.totalSupply();
        
        // Expected amounts based on proportion
        uint256 expectedAmount1 = (liquidityToRemove * reserve1Before) / totalSupplyBefore;
        uint256 expectedAmount2 = (liquidityToRemove * reserve2Before) / totalSupplyBefore;
        
        // Remove liquidity
        (uint256 amount1, uint256 amount2) = pool.removeLiquidity(liquidityToRemove);
        
        // Verify results
        assertEq(amount1, expectedAmount1, "Incorrect amount1 received");
        assertEq(amount2, expectedAmount2, "Incorrect amount2 received");
        
        // Check remaining liquidity
        assertEq(pool.balanceOf(USER1), liquidityAdded - liquidityToRemove, "Incorrect remaining LP balance");
        
        vm.stopPrank();
    }
    
    function test_removeLiquidity_revertsWhenUserHasNoLiquidity() public {
        // Create a new user who hasn't added any liquidity
        address USER_NO_LIQUIDITY = address(99);
        
        // Verify this user has zero balance
        assertEq(pool.balanceOf(USER_NO_LIQUIDITY), 0, "User should have zero LP tokens");
        
        // Try to remove liquidity as this user
        vm.startPrank(USER_NO_LIQUIDITY);
        
        // Should revert as the user has no liquidity tokens
        vm.expectRevert();
        pool.removeLiquidity(1000);
        
        vm.stopPrank();
    }
} 