// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/Factory.sol";
import "../../src/TokenFactory.sol";
import "../../src/interfaces/IPool.sol";

contract PoolGetTokensTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant FACTORY_ADDRESS = address(3);
    
    Pool public pool;
    Factory public factory;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    address public token3;
    address public token4;
    
    function setUp() public {
        // Deploy token factory and create test tokens
        vm.startPrank(OWNER);
        tokenFactory = new TokenFactory();
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 1_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 1_000_000 * 10**18);
        token3 = tokenFactory.createToken("Test Token 3", "TT3", 1_000_000 * 10**18);
        token4 = tokenFactory.createToken("Test Token 4", "TT4", 1_000_000 * 10**18);
        
        // Deploy factory
        factory = new Factory();
        vm.stopPrank();
    }
    
    function test_getTokens_directInitialization() public {
        // Deploy and initialize a pool directly
        vm.startPrank(OWNER);
        pool = new Pool();
        pool.initialize(token1, token2, FACTORY_ADDRESS);
        vm.stopPrank();
        
        // Get tokens
        (address tokenA, address tokenB) = pool.getTokens();
        
        // Verify token addresses match what was provided during initialization
        assertEq(tokenA, token1, "TokenA should match token1");
        assertEq(tokenB, token2, "TokenB should match token2");
    }
    
    function test_getTokens_factoryInitialization() public {
        // Create pool through factory
        vm.prank(OWNER);
        address poolAddress = factory.createPool(token1, token2);
        pool = Pool(poolAddress);
        
        // Get tokens
        (address tokenA, address tokenB) = pool.getTokens();
        
        // Factory might order tokens by address, so check both possibilities
        bool validOrder = (tokenA == token1 && tokenB == token2) || (tokenA == token2 && tokenB == token1);
        assertTrue(validOrder, "Tokens don't match what was provided to factory");
    }
    
    function test_getTokens_consistentTokenOrder() public {
        // Create first pool
        vm.prank(OWNER);
        address poolAddress1 = factory.createPool(token1, token2);
        Pool pool1 = Pool(poolAddress1);
        
        // Attempt to create the same pool with reversed token order
        vm.startPrank(OWNER);
        
        // This might revert if the factory prevents duplicate pools
        try factory.createPool(token2, token1) returns (address poolAddress2) {
            // If it succeeds, check that pools are the same
            Pool pool2 = Pool(poolAddress2);
            
            // Tokens should be in the same order regardless of how they were passed to factory
            (address pool1TokenA, address pool1TokenB) = pool1.getTokens();
            (address pool2TokenA, address pool2TokenB) = pool2.getTokens();
            
            assertEq(pool1TokenA, pool2TokenA, "TokenA should be consistent across pools");
            assertEq(pool1TokenB, pool2TokenB, "TokenB should be consistent across pools"); 
        } catch {
            // If it reverts, that's also acceptable behavior for a factory
            // that doesn't allow duplicate pools
        }
        
        vm.stopPrank();
    }
    
    function test_getTokens_multiplePools() public {
        // Create multiple pools with different token pairs
        vm.startPrank(OWNER);
        address poolAddress1 = factory.createPool(token1, token2);
        address poolAddress2 = factory.createPool(token3, token4);
        vm.stopPrank();
        
        // First pool tokens
        Pool pool1 = Pool(poolAddress1);
        (address pool1TokenA, address pool1TokenB) = pool1.getTokens();
        
        // Second pool tokens
        Pool pool2 = Pool(poolAddress2);
        (address pool2TokenA, address pool2TokenB) = pool2.getTokens();
        
        // Each pool should have its own token pair
        if (token1 < token2) {
            assertEq(pool1TokenA, token1, "Pool1 TokenA should match token1");
            assertEq(pool1TokenB, token2, "Pool1 TokenB should match token2");
        } else {
            assertEq(pool1TokenA, token2, "Pool1 TokenA should match token2");
            assertEq(pool1TokenB, token1, "Pool1 TokenB should match token1");
        }
        
        if (token3 < token4) {
            assertEq(pool2TokenA, token3, "Pool2 TokenA should match token3");
            assertEq(pool2TokenB, token4, "Pool2 TokenB should match token4");
        } else {
            assertEq(pool2TokenA, token4, "Pool2 TokenA should match token4");
            assertEq(pool2TokenB, token3, "Pool2 TokenB should match token3");
        }
    }
    
    function test_getTokens_immutable() public {
        // Deploy and initialize a pool directly
        vm.startPrank(OWNER);
        pool = new Pool();
        pool.initialize(token1, token2, FACTORY_ADDRESS);
        
        // Get initial token configuration
        (address initialTokenA, address initialTokenB) = pool.getTokens();
        
        // Try to re-initialize (should revert)
        vm.expectRevert("Pool: already initialized");
        pool.initialize(token3, token4, FACTORY_ADDRESS);
        vm.stopPrank();
        
        // Get tokens after failed re-initialization
        (address finalTokenA, address finalTokenB) = pool.getTokens();
        
        // Tokens should remain unchanged
        assertEq(finalTokenA, initialTokenA, "TokenA should remain unchanged after failed re-initialization");
        assertEq(finalTokenB, initialTokenB, "TokenB should remain unchanged after failed re-initialization");
    }
    
    function test_getTokens_afterOperations() public {
        // Create pool through factory
        vm.prank(OWNER);
        address poolAddress = factory.createPool(token1, token2);
        pool = Pool(poolAddress);
        
        // Setup user with tokens
        vm.startPrank(OWNER);
        TestToken(token1).mint(USER1, 100_000 * 10**18);
        TestToken(token2).mint(USER1, 100_000 * 10**18);
        vm.stopPrank();
        
        // User approves tokens and adds liquidity
        vm.startPrank(USER1);
        TestToken(token1).approve(address(pool), type(uint256).max);
        TestToken(token2).approve(address(pool), type(uint256).max);
        pool.addLiquidity(10_000 * 10**18, 10_000 * 10**18);
        
        // Perform a swap
        pool.swapExactTokensForTokens(token1, 1_000 * 10**18);
        
        // Remove liquidity
        uint256 liquidity = pool.balanceOf(USER1) / 2;
        pool.removeLiquidity(liquidity);
        vm.stopPrank();
        
        // Tokens should still be correctly reported after operations
        (address tokenA, address tokenB) = pool.getTokens();
        
        // Verify token addresses
        if (token1 < token2) {
            assertEq(tokenA, token1, "TokenA should match token1 after operations");
            assertEq(tokenB, token2, "TokenB should match token2 after operations");
        } else {
            assertEq(tokenA, token2, "TokenA should match token2 after operations");
            assertEq(tokenB, token1, "TokenB should match token1 after operations");
        }
    }
    
    function test_getTokens_multipleFactories() public {
        // Create a second factory
        vm.prank(OWNER);
        Factory factory2 = new Factory();
        
        // Create pools with same token pair but from different factories
        vm.startPrank(OWNER);
        address poolAddress1 = factory.createPool(token1, token2);
        address poolAddress2 = factory2.createPool(token1, token2);
        vm.stopPrank();
        
        // Pools should be different because they're from different factories
        assertTrue(poolAddress1 != poolAddress2, "Pool addresses should be different when created by different factories");
        
        // First pool tokens
        Pool pool1 = Pool(poolAddress1);
        (address pool1TokenA, address pool1TokenB) = pool1.getTokens();
        
        // Second pool tokens
        Pool pool2 = Pool(poolAddress2);
        (address pool2TokenA, address pool2TokenB) = pool2.getTokens();
        
        // Both pools should have the same tokens
        assertEq(pool1TokenA, pool2TokenA, "TokenA should be the same across pools");
        assertEq(pool1TokenB, pool2TokenB, "TokenB should be the same across pools");
    }
    
    function test_getTokens_interface() public {
        // Deploy and initialize a pool
        vm.startPrank(OWNER);
        pool = new Pool();
        pool.initialize(token1, token2, FACTORY_ADDRESS);
        vm.stopPrank();
        
        // Get tokens through the interface
        IPool poolInterface = IPool(address(pool));
        (address tokenA, address tokenB) = poolInterface.getTokens();
        
        // Verify token addresses match
        assertEq(tokenA, token1, "TokenA should match token1 when accessed through interface");
        assertEq(tokenB, token2, "TokenB should match token2 when accessed through interface");
    }
} 