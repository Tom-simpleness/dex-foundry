// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

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
        uint256 feeRecipientToken1Before = TestToken(token1).balanceOf(FEE_RECIPIENT);
        
        // Get reserves before swap
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        // reserveA corresponds to token2, reserveB corresponds to token1
        
        // Calculate fee amounts
        uint256 totalFeeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        uint256 protocolFeeAmount = (totalFeeAmount * PROTOCOL_FEE_PORTION) / 10000;
        uint256 lpFeeAmount = totalFeeAmount - protocolFeeAmount;
        
        // Execute swap: token1 -> token2
        uint256 amountOut = pool.swap(token1, SWAP_AMOUNT);
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before - SWAP_AMOUNT, "Incorrect token1 balance after swap");
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before + amountOut, "Incorrect token2 balance after swap");
        
        // Verify fee recipient received only the protocol portion of the fee
        assertEq(TestToken(token1).balanceOf(FEE_RECIPIENT), feeRecipientToken1Before + protocolFeeAmount, "Fee recipient didn't receive correct fee");
        
        // Verify reserves changed properly, including the LP portion of the fee
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveBAfter, reserveB + SWAP_AMOUNT - protocolFeeAmount, "ReserveB (token1) incorrect after swap");
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
        
        // Calculate fee amounts
        uint256 totalFeeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        uint256 protocolFeeAmount = (totalFeeAmount * PROTOCOL_FEE_PORTION) / 10000;
        uint256 lpFeeAmount = totalFeeAmount - protocolFeeAmount;
        
        // Execute swap: token2 -> token1
        uint256 amountOut = pool.swap(token2, SWAP_AMOUNT);
        
        // Verify output amount
        assertGt(amountOut, 0, "Output amount should be greater than 0");
        
        // Verify user's balances changed correctly
        assertEq(TestToken(token2).balanceOf(USER2), user2Token2Before - SWAP_AMOUNT, "Incorrect token2 balance after swap");
        assertEq(TestToken(token1).balanceOf(USER2), user2Token1Before + amountOut, "Incorrect token1 balance after swap");
        
        // Verify fee recipient received only the protocol portion of the fee
        assertEq(TestToken(token2).balanceOf(FEE_RECIPIENT), feeRecipientToken2Before + protocolFeeAmount, "Fee recipient didn't receive correct fee");
        
        // Verify reserves changed properly, including the LP portion of the fee
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        assertEq(reserveAAfter, reserveA + SWAP_AMOUNT - protocolFeeAmount, "ReserveA (token2) incorrect after swap");
        assertEq(reserveBAfter, reserveB - amountOut, "ReserveB (token1) incorrect after swap");
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithInvalidToken() public {
        vm.startPrank(USER2);
        
        // Deploy a new token not associated with this pool
        address invalidToken = tokenFactory.createToken("Invalid Token", "INV", 1_000_000 * 10**18);
        
        // Try to swap with invalid token
        vm.expectRevert("Pool: invalid input token");
        pool.swap(invalidToken, SWAP_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_swap_revertsWithZeroAmount() public {
        vm.startPrank(USER2);
        
        // Try to swap with zero amount
        vm.expectRevert("Pool: insufficient input amount");
        pool.swap(token1, 0);
        
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
        uint256 token2Out = pool.swap(token1, SWAP_AMOUNT);
        cumulativeToken1Spent += SWAP_AMOUNT;
        cumulativeToken2Received += token2Out;
        
        // Second swap: token2 -> token1
        uint256 token1Out = pool.swap(token2, SWAP_AMOUNT);
        cumulativeToken2Spent += SWAP_AMOUNT;
        cumulativeToken1Received += token1Out;
        
        // Third swap: token1 -> token2 (smaller amount)
        uint256 smallAmount = SWAP_AMOUNT / 2;
        uint256 token2OutSmall = pool.swap(token1, smallAmount);
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
        pool.swap(token1, excessiveAmount);
        
        vm.stopPrank();
    }
    
    function test_swap_invariantMaintained() public {
        vm.startPrank(USER2);
        
        // Get initial K
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        uint256 kBefore = reserveA * reserveB;
        
        // Execute swap
        pool.swap(token1, SWAP_AMOUNT);
        
        // Get new K (after fee extraction)
        (uint256 reserveAAfter, uint256 reserveBAfter) = pool.getReserves();
        uint256 kAfter = reserveAAfter * reserveBAfter;
        
        // K value should increase or stay the same due to fees retained in the pool
        assertGe(kAfter, kBefore, "K value decreased after swap");
        
        vm.stopPrank();
    }

    function test_protocolFeePortion_affectsDistribution() public {
        // Test with just one specific portion value instead of a loop
        // to avoid overflow issues
        vm.startPrank(OWNER);
        factory.setProtocolFeePortion(7000); // 70% to protocol
        vm.stopPrank();

        // Record initial balances
        uint256 initialFeeRecipient = TestToken(token1).balanceOf(FEE_RECIPIENT);
        (uint256 initialReserveA, uint256 initialReserveB) = pool.getReserves();
        
        // Execute swap
        vm.startPrank(USER2);
        pool.swap(token1, SWAP_AMOUNT);
        vm.stopPrank();
        
        // Calculate expected fee amounts
        uint256 totalFeeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        uint256 expectedProtocolFee = (totalFeeAmount * 7000) / 10000;
        
        // Check fee recipient received the correct amount
        uint256 actualProtocolFee = TestToken(token1).balanceOf(FEE_RECIPIENT) - initialFeeRecipient;
        assertEq(actualProtocolFee, expectedProtocolFee, "Protocol fee amount incorrect");
        
        // Check reserve increase includes LP portion of fee
        (uint256 finalReserveA, uint256 finalReserveB) = pool.getReserves();
        uint256 expectedReserveIncrease = SWAP_AMOUNT - expectedProtocolFee;
        assertEq(finalReserveB - initialReserveB, expectedReserveIncrease, "LP portion not correctly added to reserves");
    }

    function test_lpValueIncreasesFromFees() public {
        // Set all fees to go to LPs, none to protocol
        vm.prank(OWNER);
        factory.setProtocolFeePortion(0);
        
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
            pool.swap(token1, SWAP_AMOUNT);
            pool.swap(token2, SWAP_AMOUNT);
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
        // Set 0% of fees to go to protocol (100% to LPs)
        factory.setProtocolFeePortion(0);
        vm.stopPrank();
        
        // Record initial balances
        uint256 initialFeeRecipient = TestToken(token1).balanceOf(FEE_RECIPIENT);
        (uint256 initialReserveA, uint256 initialReserveB) = pool.getReserves();
        
        // Execute swap
        vm.startPrank(USER2);
        pool.swap(token1, SWAP_AMOUNT);
        vm.stopPrank();
        
        // Calculate total fee
        uint256 totalFeeAmount = (SWAP_AMOUNT * FEE_RATE) / 10000;
        
        // Verify fee recipient got nothing
        assertEq(TestToken(token1).balanceOf(FEE_RECIPIENT), initialFeeRecipient, "Fee recipient should not receive any fees");
        
        // Verify all fees stayed in the pool
        (uint256 finalReserveA, uint256 finalReserveB) = pool.getReserves();
        assertEq(finalReserveB - initialReserveB, SWAP_AMOUNT, "All fees should remain in the pool");
    }
} 