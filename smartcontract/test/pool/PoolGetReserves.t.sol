// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/PoolFactory.sol";
import "../../src/mocks/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";
import "../../src/interfaces/IPoolFactory.sol";

contract PoolGetReservesTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant FACTORY = address(3);
    
    Pool public pool;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    // Common liquidity values for testing
    uint256 constant INITIAL_AMOUNT1 = 100_000 * 10**18;
    uint256 constant INITIAL_AMOUNT2 = 200_000 * 10**18;
    
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
        vm.stopPrank();
        
        // Approve tokens for pool
        vm.startPrank(USER1);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_getReserves_initialState() public {
        // Test initial state before any liquidity is added
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        
        // Initial reserves should be zero
        assertEq(reserve1, 0, "Initial reserve1 should be 0");
        assertEq(reserve2, 0, "Initial reserve2 should be 0");
    }
    
    function test_getReserves_afterAddLiquidity() public {
        // Add liquidity
        vm.prank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Check reserves after adding liquidity
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        
        // Reserves should match the added amounts
        assertEq(reserve1, INITIAL_AMOUNT1, "Reserve1 should match added amount");
        assertEq(reserve2, INITIAL_AMOUNT2, "Reserve2 should match added amount");
    }
    
    function test_getReserves_afterRemoveLiquidity() public {
        // Add liquidity first
        vm.startPrank(USER1);
        uint256 liquidity = pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Get reserves before removal
        (uint256 reserveBefore1, uint256 reserveBefore2) = pool.getReserves();
        
        // Remove half of the liquidity
        uint256 halfLiquidity = liquidity / 2;
        pool.removeLiquidity(halfLiquidity);
        vm.stopPrank();
        
        // Get reserves after removal
        (uint256 reserveAfter1, uint256 reserveAfter2) = pool.getReserves();
        
        // Reserves should be reduced by approximately half
        assertApproxEqRel(reserveAfter1, reserveBefore1 / 2, 1e16, "Reserve1 should be reduced by half");
        assertApproxEqRel(reserveAfter2, reserveBefore2 / 2, 1e16, "Reserve2 should be reduced by half");
    }
    
    function test_getReserves_afterSwap() public {
        // Add initial liquidity
        vm.prank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Setup factory and fee recipient for swap test
        address feeRecipient = address(10);
        vm.startPrank(FACTORY);
        PoolFactory factoryContract = new PoolFactory();
        factoryContract.setFee(300); // 0.3%
        factoryContract.setFeeRecipient(feeRecipient);
        factoryContract.setProtocolFeePortion(10000); // 100% goes to protocol for simplicity
        vm.stopPrank();
        
        // Mock the factory address to return our test factory
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getFee.selector),
            abi.encode(300)
        );
        
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getFeeRecipient.selector),
            abi.encode(feeRecipient)
        );

        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getProtocolFeePortion.selector),
            abi.encode(10000) // 100% goes to protocol
        );
        
        // Get reserves before swap
        (uint256 reserveBefore1, uint256 reserveBefore2) = pool.getReserves();
        
        // Perform a swap
        uint256 swapAmount = 1_000 * 10**18;
        vm.startPrank(USER1);
        uint256 outputAmount = pool.swap(token1, swapAmount);
        vm.stopPrank();
        
        // Get reserves after swap
        (uint256 reserveAfter1, uint256 reserveAfter2) = pool.getReserves();
        
        // Calculate expected fee and amount that should be added to reserve
        uint256 fee = (swapAmount * 300) / 10000; // 0.3% fee
        uint256 expectedAmountAddedToReserve = swapAmount - fee;
        
        // Verify reserves changed correctly
        assertEq(reserveAfter1, reserveBefore1 + expectedAmountAddedToReserve, 
                "Reserve1 should increase by swap amount minus fee");
        assertEq(reserveAfter2, reserveBefore2 - outputAmount, 
                "Reserve2 should decrease by output amount");
    }
    
    function test_getReserves_multipleOperations() public {
        // Setup factory and fee recipient
        address feeRecipient = address(10);
        vm.startPrank(FACTORY);
        PoolFactory factoryContract = new PoolFactory();
        factoryContract.setFee(300); // 0.3%
        factoryContract.setFeeRecipient(feeRecipient);
        factoryContract.setProtocolFeePortion(10000); // 100% to protocol
        vm.stopPrank();
        
        // Mock the factory address to return our test factory
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getFee.selector),
            abi.encode(300)
        );
        
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getFeeRecipient.selector),
            abi.encode(feeRecipient)
        );
        
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IPoolFactory.getProtocolFeePortion.selector),
            abi.encode(10000) // 100% goes to protocol
        );
        
        vm.startPrank(USER1);
        
        // Add initial liquidity
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        (uint256 initialReserve1, uint256 initialReserve2) = pool.getReserves();
        
        // First swap: token1 to token2
        uint256 swapAmount1 = 5_000 * 10**18;
        pool.swap(token1, swapAmount1);
        
        // Get reserves after first operation sequence
        (uint256 reserve1After1, uint256 reserve2After1) = pool.getReserves();
        
        // Add more liquidity
        uint256 additionalAmount1 = 10_000 * 10**18;
        uint256 additionalAmount2 = 15_000 * 10**18;
        pool.addLiquidity(additionalAmount1, additionalAmount2);
        
        // Get reserves after second operation
        (uint256 reserve1After2, uint256 reserve2After2) = pool.getReserves();
        
        // Second swap: token2 to token1
        uint256 swapAmount2 = 8_000 * 10**18;
        pool.swap(token2, swapAmount2);
        
        // Get reserves after third operation
        (uint256 reserve1After3, uint256 reserve2After3) = pool.getReserves();
        
        // Simply verify each step caused changes
        assertGt(reserve1After1, initialReserve1, "Reserve1 should increase after first swap");
        assertLt(reserve2After1, initialReserve2, "Reserve2 should decrease after first swap");
        
        assertGt(reserve1After2, reserve1After1, "Reserve1 should increase after adding more liquidity");
        assertGt(reserve2After2, reserve2After1, "Reserve2 should increase after adding more liquidity");
        
        assertLt(reserve1After3, reserve1After2, "Reserve1 should decrease after swapping token2 for token1");
        assertGt(reserve2After3, reserve2After2, "Reserve2 should increase after swapping token2 for token1");
        
        vm.stopPrank();
    }
    
    function test_getReserves_directManipulation() public {
        // Add initial liquidity
        vm.prank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Get initial reserves
        (uint256 reserve1Before, uint256 reserve2Before) = pool.getReserves();
        
        // Attempt to directly manipulate reserves by sending tokens to the pool
        // This shouldn't affect the reserves until a pool function is called
        vm.startPrank(USER1);
        TestToken(token1).transfer(address(pool), 10_000 * 10**18);
        vm.stopPrank();
        
        // Check reserves after direct token transfer
        (uint256 reserve1After, uint256 reserve2After) = pool.getReserves();
        
        // Reserves should not change until a pool function is called
        assertEq(reserve1After, reserve1Before, "Reserve1 should not change after direct token transfer");
        assertEq(reserve2After, reserve2Before, "Reserve2 should not change after direct token transfer");
        
        // Now call a pool function to trigger reserve update
        vm.prank(USER1);
        pool.addLiquidity(1 * 10**18, 2 * 10**18);
        
        // Check reserves after pool function is called
        (uint256 reserve1Updated, uint256 reserve2Updated) = pool.getReserves();
        
        // Reserves should now reflect all tokens in the pool
        assertGt(reserve1Updated, reserve1Before + 1 * 10**18, "Reserve1 should include directly transferred tokens");
        assertEq(reserve2Updated, reserve2Before + 2 * 10**18, "Reserve2 should match expected amount");
    }
    
    function test_getReserves_consistency() public {
        // Verify that getReserves returns the same values consistently
        vm.prank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Call getReserves multiple times
        (uint256 reserve1First, uint256 reserve2First) = pool.getReserves();
        (uint256 reserve1Second, uint256 reserve2Second) = pool.getReserves();
        (uint256 reserve1Third, uint256 reserve2Third) = pool.getReserves();
        
        // All calls should return the same values
        assertEq(reserve1First, reserve1Second, "Reserve1 should be consistent across calls");
        assertEq(reserve1Second, reserve1Third, "Reserve1 should be consistent across calls");
        assertEq(reserve2First, reserve2Second, "Reserve2 should be consistent across calls");
        assertEq(reserve2Second, reserve2Third, "Reserve2 should be consistent across calls");
    }
    
    function test_getReserves_orderPreservation() public {
        // Add initial liquidity
        vm.prank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        
        // Get reserves
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        
        // Verify token order is preserved (reserve1 corresponds to tokenA, reserve2 to tokenB)
        assertEq(reserve1, INITIAL_AMOUNT1, "Reserve1 should correspond to token1 amount");
        assertEq(reserve2, INITIAL_AMOUNT2, "Reserve2 should correspond to token2 amount");
        
        // Verify by checking token balances directly
        assertEq(TestToken(token1).balanceOf(address(pool)), reserve1, "Reserve1 should match token1 balance");
        assertEq(TestToken(token2).balanceOf(address(pool)), reserve2, "Reserve2 should match token2 balance");
    }
} 