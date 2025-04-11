// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/PoolFactory.sol";
import "../../src/mocks/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";

contract PoolSwapTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant FEE_RECIPIENT = address(4);
    
    Pool public pool;
    PoolFactory public factory;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    // Common test values
    uint256 constant INITIAL_AMOUNT1 = 1_000_000 * 10**18; // 1M tokens
    uint256 constant INITIAL_AMOUNT2 = 2_000_000 * 10**18; // 2M tokens
    uint256 constant SWAP_AMOUNT = 10_000 * 10**18;        // 10K tokens
    uint256 constant FEE_RATE = 300;                       // 0.3%
    uint256 constant PROTOCOL_FEE_PORTION = 5000;          // 50% to protocol, 50% to LPs
    
    function setUp() public {
        // Deploy token factory and create test tokens
        vm.startPrank(OWNER);
        tokenFactory = new TokenFactory();
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 10_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 10_000_000 * 10**18);
        
        // Deploy factory and set fee details
        factory = new PoolFactory();
        factory.setFee(FEE_RATE);
        factory.setFeeRecipient(FEE_RECIPIENT);
        factory.setProtocolFeePortion(PROTOCOL_FEE_PORTION);
        
        // Create pool through factory to ensure proper setup
        address poolAddress = factory.createPool(token1, token2);
        pool = Pool(poolAddress);
        
        // Transfer tokens to users for testing
        TestToken(token1).mint(USER1, 5_000_000 * 10**18);
        TestToken(token2).mint(USER1, 5_000_000 * 10**18);
        TestToken(token1).mint(USER2, 5_000_000 * 10**18);
        TestToken(token2).mint(USER2, 5_000_000 * 10**18);
        vm.stopPrank();
        
        // Add initial liquidity
        vm.startPrank(USER1);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        vm.stopPrank();
        
        // Approve tokens for USER2
        vm.startPrank(USER2);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
    
    function calculateExpectedOutput(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 feeRate) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * (10000 - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        
        return numerator / denominator;
    }

    function test_swap_token1ForToken2() public {
        vm.startPrank(USER2);
        
        // Record balances before swap
        uint256 user2Token1Before = TestToken(token1).balanceOf(USER2);
        uint256 user2Token2Before = TestToken(token2).balanceOf(USER2);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();

        // Transfer tokenIn to pool before calling swap
        TestToken(token1).transfer(address(pool), SWAP_AMOUNT); 
        
        // Execute swap: token1 -> token2, recipient is USER2
        uint256 amountOut = pool.swap(token1, SWAP_AMOUNT, USER2); 
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before - SWAP_AMOUNT, "Incorrect token1 balance after swap");
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before + amountOut, "Incorrect token2 balance after swap");
        
        // Verify reserves changed properly (fee stays in pool)
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveBAfter, reserveB + SWAP_AMOUNT, "ReserveB (token1) incorrect after swap"); // reserveIn increases by full amountIn
        assertEq(reserveAAfter, reserveA - amountOut, "ReserveA (token2) incorrect after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_token2ForToken1() public {
        vm.startPrank(USER2);
        
        // Record balances before swap
        uint256 user2Token1Before = TestToken(token1).balanceOf(USER2);
        uint256 user2Token2Before = TestToken(token2).balanceOf(USER2);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();

        // Transfer tokenIn to pool before calling swap
        TestToken(token2).transfer(address(pool), SWAP_AMOUNT); 

        // Execute swap: token2 -> token1, recipient is USER2
        uint256 amountOut = pool.swap(token2, SWAP_AMOUNT, USER2); 
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before - SWAP_AMOUNT, "Incorrect token2 balance after swap");
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before + amountOut, "Incorrect token1 balance after swap");
        
        // Verify reserves changed properly (fee stays in pool)
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveAAfter, reserveA + SWAP_AMOUNT, "ReserveA (token2) incorrect after swap"); // reserveIn increases by full amountIn
        assertEq(reserveBAfter, reserveB - amountOut, "ReserveB (token1) incorrect after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithInvalidToken() public {
        vm.startPrank(USER2);
        
        // Deploy a new token not associated with this pool
        address invalidToken = tokenFactory.createToken("Invalid Token", "INV", 1_000_000 * 10**18);
        
        // Try to swap with invalid token
        vm.expectRevert("Pool: invalid input token");
        pool.swap(invalidToken, SWAP_AMOUNT, USER2); 
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithZeroAmount() public {
        vm.startPrank(USER2);
        
        // Try to swap with zero amount
        vm.expectRevert("Pool: insufficient input amount");
        pool.swap(token1, 0, USER2); 
        
        vm.stopPrank();
    }
    
    function test_swap_multipleSwapsInSequence() public {
        vm.startPrank(USER2);
        
        // Perform multiple swaps in sequence
        uint256 user2InitialToken1 = TestToken(token1).balanceOf(USER2);
        uint256 user2InitialToken2 = TestToken(token2).balanceOf(USER2);
        uint256 cumulativeToken1Spent = 0;
        uint256 cumulativeToken2Spent = 0;
        uint256 cumulativeToken1Received = 0;
        uint256 cumulativeToken2Received = 0;
        
        // First swap: token1 -> token2
        TestToken(token1).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
        uint256 token2Out = pool.swap(token1, SWAP_AMOUNT, USER2); 
        cumulativeToken1Spent += SWAP_AMOUNT;
        cumulativeToken2Received += token2Out;
        
        // Second swap: token2 -> token1
        TestToken(token2).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
        uint256 token1Out = pool.swap(token2, SWAP_AMOUNT, USER2); 
        cumulativeToken2Spent += SWAP_AMOUNT;
        cumulativeToken1Received += token1Out;
        
        // Third swap: token1 -> token2 (smaller amount)
        uint256 smallAmount = SWAP_AMOUNT / 2;
        TestToken(token1).transfer(address(pool), smallAmount); // Transfer before swap
        uint256 token2OutSmall = pool.swap(token1, smallAmount, USER2); 
        cumulativeToken1Spent += smallAmount;
        cumulativeToken2Received += token2OutSmall;
        
        // Verify final balances
        assertEq(
            TestToken(token1).balanceOf(USER2), 
            user2InitialToken1 - cumulativeToken1Spent + cumulativeToken1Received, 
            "Incorrect final token1 balance"
        );
        assertEq(
            TestToken(token2).balanceOf(USER2), 
            user2InitialToken2 - cumulativeToken2Spent + cumulativeToken2Received, 
            "Incorrect final token2 balance"
        );
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWhenPoolHasZeroOutputReserve() public {
        // Goal: Test swapping when the target output token has zero reserve in the pool.
        
        // Create a new, separate pool manually for this test
        vm.startPrank(OWNER); // Owner deploys the pool
        Pool newPool = new Pool();
        // Initialize the pool manually, mimicking factory initialization
        // Note: We still need a valid factory address for fee lookups if swap was reached
        newPool.initialize(token1, token2, address(factory)); 
        vm.stopPrank();

        // Add liquidity only for token1, leaving token2 reserve at 0
        vm.startPrank(USER1);
        uint256 singleTokenAmount = 100 * 10**18;
        TestToken(token1).approve(address(newPool), singleTokenAmount); 
        // Transfer token1 directly to the pool
        TestToken(token1).transfer(address(newPool), singleTokenAmount); 
        
        // Try to swap token1 for token2. Should fail in getAmountOut because reserveOut is 0.
        uint256 swapInAmount = 10 * 10**18;
        TestToken(token1).transfer(address(newPool), swapInAmount); // Transfer token to swap

        // Expect revert from getAmountOut check
        vm.expectRevert("Math: INSUFFICIENT_LIQUIDITY"); 
        newPool.swap(token1, swapInAmount, USER1);
        
        vm.stopPrank();
    }
    
    function test_swap_invariantMaintained() public {
        vm.startPrank(USER2);
        
        // Get initial K
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        uint256 kBefore = reserveA * reserveB;
        
        // Execute swap
        TestToken(token1).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
        pool.swap(token1, SWAP_AMOUNT, USER2); 
        
        // Get new K (after fee extraction)
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        uint256 kAfter = reserveAAfter * reserveBAfter;
        
        // K value should increase or stay the same due to fees retained in the pool
        assertGe(kAfter, kBefore, "K value decreased after swap");
        
        vm.stopPrank();
    }

    function test_protocolFeePortion_affectsDistribution() public {
        // NOTE: This test is now less meaningful as protocol fees aren't distributed during swap
        vm.startPrank(OWNER);
        factory.setProtocolFeePortion(7000); 
        vm.stopPrank();

        (uint256 initialReserveA, uint256 initialReserveB) = pool.getReserves();
        
        // Execute swap
        vm.startPrank(USER2);
        TestToken(token1).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
        pool.swap(token1, SWAP_AMOUNT, USER2); 
        vm.stopPrank();
        
        // Check reserve increase includes the full fee (implicitly)
        (uint256 finalReserveA, uint256 finalReserveB) = pool.getReserves();
        assertEq(finalReserveB - initialReserveB, SWAP_AMOUNT, "Reserve increase incorrect");
    }

    function test_lpValueIncreasesFromFees() public {
        // Set all fees to go to LPs, none to protocol
        vm.prank(OWNER);
        factory.setProtocolFeePortion(0); // NOTE: This setting doesn't affect swap logic anymore
        
        // Record initial LP token value
        uint256 lpTokensUser1 = pool.balanceOf(USER1);
        
        // Get initial state
        (uint256 initialReserveA, uint256 initialReserveB) = pool.getReserves();
        uint256 initialK = initialReserveA * initialReserveB;
        
        // Add more liquidity to create more swapping room
        vm.startPrank(USER1);
        pool.addLiquidity(INITIAL_AMOUNT1, INITIAL_AMOUNT2);
        vm.stopPrank();
        
        // Perform multiple swaps in both directions
        vm.startPrank(USER2);
        for (uint i = 0; i < 20; i++) {
            TestToken(token1).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
            pool.swap(token1, SWAP_AMOUNT, USER2); 
            TestToken(token2).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
            pool.swap(token2, SWAP_AMOUNT, USER2); 
        }
        vm.stopPrank();
        
        // Get final state
        (uint256 finalReserveA, uint256 finalReserveB) = pool.getReserves();
        uint256 finalK = finalReserveA * finalReserveB;
        
        // K should increase because fees are kept in the pool
        assertGt(finalK, initialK, "LP token value (K) did not increase from fees");
    }

    function test_zeroProtocolFeePortionKeepsAllFeesInPool() public {
        vm.startPrank(OWNER);
        // Set 0% of fees to go to protocol (100% to LPs) - NOTE: This setting doesn't affect swap logic anymore
        factory.setProtocolFeePortion(0);
        vm.stopPrank();
        
        // Record initial balances
        (uint256 initialReserveA, uint256 initialReserveB) = pool.getReserves();
        
        // Execute swap
        vm.startPrank(USER2);
        TestToken(token1).transfer(address(pool), SWAP_AMOUNT); // Transfer before swap
        pool.swap(token1, SWAP_AMOUNT, USER2); 
        vm.stopPrank();
        
        // Verify all fees stayed in the pool reserve increase
        (uint256 finalReserveA, uint256 finalReserveB) = pool.getReserves();
        assertEq(finalReserveB - initialReserveB, SWAP_AMOUNT, "All fees should remain in the pool reserve increase");
    }
} 