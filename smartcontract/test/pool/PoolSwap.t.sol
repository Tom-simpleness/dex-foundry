// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/Factory.sol";
import "../../src/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";

contract PoolSwapTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant FEE_RECIPIENT = address(4);
    
    Pool public pool;
    Factory public factory;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    // Common test values
    uint256 constant INITIAL_AMOUNT1 = 1_000_000 * 10**18; // 1M tokens
    uint256 constant INITIAL_AMOUNT2 = 2_000_000 * 10**18; // 2M tokens
    uint256 constant SWAP_AMOUNT = 10_000 * 10**18;        // 10K tokens
    uint256 constant FEE_RATE = 300;                       // 0.3%
    
    function setUp() public {
        // Deploy token factory and create test tokens
        vm.startPrank(OWNER);
        tokenFactory = new TokenFactory();
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 10_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 10_000_000 * 10**18);
        
        // Deploy factory and set fee details
        factory = new Factory();
        factory.setFee(FEE_RATE);
        factory.setFeeRecipient(FEE_RECIPIENT);
        
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
    
    // Cette fonction remplace nos calculs précédents pour être cohérente avec Math.getAmountOut
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
        uint256 feeRecipientToken1Before = TestToken(token1).balanceOf(FEE_RECIPIENT);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        // reserveA corresponds to token2, reserveB corresponds to token1
        
        // Calculate fee amount
        uint256 feeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        
        // Execute swap: token1 -> token2
        uint256 amountOut = pool.swapExactTokensForTokens(token1, SWAP_AMOUNT);
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before - SWAP_AMOUNT, "Incorrect token1 balance after swap");
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before + amountOut, "Incorrect token2 balance after swap");
        
        // Verify fee recipient received fee
        assertEq(TestToken(token1).balanceOf(FEE_RECIPIENT), feeRecipientToken1Before + feeAmount, "Fee recipient didn't receive correct fee");
        
        // Verify reserves changed in the right direction:
        // token1 is tokenB in the pool, so reserveB should increase
        // token2 is tokenA in the pool, so reserveA should decrease
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveBAfter, reserveB + SWAP_AMOUNT - feeAmount, "ReserveB (token1) incorrect after swap");
        assertEq(reserveAAfter, reserveA - amountOut, "ReserveA (token2) incorrect after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_token2ForToken1() public {
        vm.startPrank(USER2);
        
        // Record balances before swap
        uint256 user2Token1Before = TestToken(token1).balanceOf(USER2);
        uint256 user2Token2Before = TestToken(token2).balanceOf(USER2);
        uint256 feeRecipientToken2Before = TestToken(token2).balanceOf(FEE_RECIPIENT);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        // reserveA corresponds to token2, reserveB corresponds to token1
        
        // Calculate fee amount
        uint256 feeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        
        // Execute swap: token2 -> token1
        uint256 amountOut = pool.swapExactTokensForTokens(token2, SWAP_AMOUNT);
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before - SWAP_AMOUNT, "Incorrect token2 balance after swap");
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before + amountOut, "Incorrect token1 balance after swap");
        
        // Verify fee recipient received fee
        assertEq(TestToken(token2).balanceOf(FEE_RECIPIENT), feeRecipientToken2Before + feeAmount, "Fee recipient didn't receive correct fee");
        
        // Verify reserves changed in the right direction:
        // token2 is tokenA in the pool, so reserveA should increase
        // token1 is tokenB in the pool, so reserveB should decrease
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveAAfter, reserveA + SWAP_AMOUNT - feeAmount, "ReserveA (token2) incorrect after swap");
        assertEq(reserveBAfter, reserveB - amountOut, "ReserveB (token1) incorrect after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithInvalidToken() public {
        vm.startPrank(USER2);
        
        // Deploy a new token not associated with this pool
        address invalidToken = tokenFactory.createToken("Invalid Token", "INV", 1_000_000 * 10**18);
        
        // Try to swap with invalid token
        vm.expectRevert("Pool: invalid input token");
        pool.swapExactTokensForTokens(invalidToken, SWAP_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithZeroAmount() public {
        vm.startPrank(USER2);
        
        // Try to swap with zero amount
        vm.expectRevert("Pool: insufficient input amount");
        pool.swapExactTokensForTokens(token1, 0);
        
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
        uint256 token2Out = pool.swapExactTokensForTokens(token1, SWAP_AMOUNT);
        cumulativeToken1Spent += SWAP_AMOUNT;
        cumulativeToken2Received += token2Out;
        
        // Second swap: token2 -> token1
        uint256 token1Out = pool.swapExactTokensForTokens(token2, SWAP_AMOUNT);
        cumulativeToken2Spent += SWAP_AMOUNT;
        cumulativeToken1Received += token1Out;
        
        // Third swap: token1 -> token2 (smaller amount)
        uint256 smallAmount = SWAP_AMOUNT / 2;
        uint256 token2OutSmall = pool.swapExactTokensForTokens(token1, smallAmount);
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
    
    function test_swap_sufficientLiquidity() public {
        vm.startPrank(USER2);
        
        // Try to swap a very large amount - should revert due to insufficient user balance
        // Even though we have approval, USER2 doesn't have enough tokens
        uint256 excessiveAmount = INITIAL_AMOUNT1 * 100;
        
        // Set a high approval first
        TestToken(token1).approve(address(pool), excessiveAmount);
        
        // Attempt to swap a huge amount should revert with ERC20 insufficient balance error
        // Expecting an ERC20 error rather than Math error since the transfer will fail first
        vm.expectRevert();
        pool.swapExactTokensForTokens(token1, excessiveAmount);
        
        vm.stopPrank();
    }
    
    function test_swap_invariantMaintained() public {
        vm.startPrank(USER2);
        
        // Get initial K
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        uint256 kBefore = reserveA * reserveB;
        
        // Execute swap
        pool.swapExactTokensForTokens(token1, SWAP_AMOUNT);
        
        // Get new K (after fee extraction)
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        uint256 kAfter = reserveAAfter * reserveBAfter;
        
        // K value should increase or stay the same due to fees
        assertGe(kAfter, kBefore, "K value decreased after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_differentUsers() public {
        // Another user for testing
        address USER3 = address(5);
        
        // Setup USER3
        vm.startPrank(OWNER);
        TestToken(token1).mint(USER3, 1_000_000 * 10**18);
        TestToken(token2).mint(USER3, 1_000_000 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(USER3);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        // First user swaps token1 for token2
        vm.prank(USER2);
        uint256 output1 = pool.swapExactTokensForTokens(token1, SWAP_AMOUNT);
        
        // Second user swaps token2 for token1
        vm.prank(USER3);
        uint256 output2 = pool.swapExactTokensForTokens(token2, SWAP_AMOUNT);
        
        // Both outputs should be non-zero
        assertGt(output1, 0, "First swap output should be greater than 0");
        assertGt(output2, 0, "Second swap output should be greater than 0");
    }
    
    function test_swap_withFeeChange() public {
        // First do a swap with initial fee
        vm.prank(USER2);
        pool.swapExactTokensForTokens(token1, SWAP_AMOUNT);
        
        // Change fee rate
        uint256 newFeeRate = 100; // 0.1%
        vm.prank(OWNER);
        factory.setFee(newFeeRate);
        
        // Do another swap with new fee
        vm.startPrank(USER2);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        
        // Execute swap
        uint256 output2 = pool.swapExactTokensForTokens(token2, SWAP_AMOUNT);
        
        // Verify output is greater than zero
        assertGt(output2, 0, "Output should be greater than 0");
        
        vm.stopPrank();
    }
    
    function test_fuzz_swap(uint128 amount) public {
        // Ensure amount is reasonable (not too small, not too large)
        vm.assume(amount > 100);
        vm.assume(amount < INITIAL_AMOUNT1 / 10); // Limit to smaller values for stability
        
        vm.startPrank(USER2);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        // reserveA corresponds to token2, reserveB corresponds to token1
        
        // Calculate fee amount
        uint256 feeAmount = (uint256(amount) * FEE_RATE) / 10000;
        
        // Execute swap
        uint256 actualOutput = pool.swapExactTokensForTokens(token1, amount);
        
        // Verify output is reasonable
        assertGt(actualOutput, 0, "Output should be greater than 0");
        
        // Verify reserves changed correctly:
        // token1 is tokenB in the pool, so reserveB should increase
        // token2 is tokenA in the pool, so reserveA should decrease
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveBAfter, reserveB + amount - feeAmount, "ReserveB (token1) incorrect after swap");
        assertEq(reserveAAfter, reserveA - actualOutput, "ReserveA (token2) incorrect after swap");
        
        vm.stopPrank();
    }
} 