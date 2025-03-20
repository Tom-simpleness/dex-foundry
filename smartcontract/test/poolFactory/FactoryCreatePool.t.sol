// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/PoolFactory.sol";
import "../../src/Pool.sol";
import "../../src/TokenFactory.sol";
import "../../src/interfaces/IPoolFactory.sol";

contract FactoryCreatePoolTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    
    PoolFactory public factory;
    TokenFactory public tokenFactory;
    address public token1;
    address public token2;
    
    function setUp() public {
        vm.startPrank(OWNER);
        factory = new PoolFactory();
        tokenFactory = new TokenFactory();
        
        // Create test tokens
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 1_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 1_000_000 * 10**18);
        vm.stopPrank();
    }
    
    function test_createPool_succeeds() public {
        vm.startPrank(USER1);
        
        // Check initial state
        address initialPool = factory.getPool(token1, token2);
        assertEq(initialPool, address(0), "Pool should not exist yet");
        
        // Create pool
        address poolAddress = factory.createPool(token1, token2);
        
        // Verify pool was created
        assertTrue(poolAddress != address(0), "Pool address should not be zero");
        assertEq(factory.getPool(token1, token2), poolAddress, "Pool should be retrievable with getPool");
        assertEq(factory.getPool(token2, token1), poolAddress, "Pool should be retrievable with tokens in reverse order");
        
        // Verify pool was initialized correctly
        Pool pool = Pool(poolAddress);
        (address poolToken1, address poolToken2) = pool.getTokens();
        if (token1 < token2) {
            assertEq(poolToken1, token1, "Token1 not set correctly");
            assertEq(poolToken2, token2, "Token2 not set correctly");
        } else {
            assertEq(poolToken1, token2, "Token1 not set correctly");
            assertEq(poolToken2, token1, "Token2 not set correctly");
        }
        
        vm.stopPrank();
    }
    
    function test_createPool_emitsPoolCreatedEvent() public {
        vm.startPrank(USER1);
        
        // Prepare for event checking
        (address token0, address token1_) = token1 < token2 ? (token1, token2) : (token2, token1);
        
        // Check for event emission
        vm.expectEmit(true, true, true, false); // Check for indexed params
        emit IPoolFactory.PoolCreated(token0, token1_, address(0), 1); // We don't check the pool address as we don't know it in advance
        
        // Create pool
        factory.createPool(token1, token2);
        
        vm.stopPrank();
    }
    
    function test_createPool_revertWhenIdenticalAddresses() public {
        vm.startPrank(USER1);
        
        vm.expectRevert("Factory: identical addresses");
        factory.createPool(token1, token1);
        
        vm.stopPrank();
    }
    
    function test_createPool_revertWhenZeroAddress() public {
        vm.startPrank(USER1);
        
        vm.expectRevert("Factory: zero address");
        factory.createPool(token1, address(0));
        
        vm.expectRevert("Factory: zero address");
        factory.createPool(address(0), token2);
        
        vm.stopPrank();
    }
    
    function test_createPool_revertWhenPoolExists() public {
        vm.startPrank(USER1);
        
        // Create pool first time
        factory.createPool(token1, token2);
        
        // Try to create same pool again
        vm.expectRevert("Factory: pool exists");
        factory.createPool(token1, token2);
        
        // Try to create with tokens in reverse order
        vm.expectRevert("Factory: pool exists");
        factory.createPool(token2, token1);
        
        vm.stopPrank();
    }
    
    function test_createPool_multiplePoolsWithDifferentTokens() public {
        vm.startPrank(OWNER);
        address token3 = tokenFactory.createToken("Test Token 3", "TT3", 1_000_000 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(USER1);
        
        // Create first pool
        address pool1 = factory.createPool(token1, token2);
        
        // Create second pool with different token pair
        address pool2 = factory.createPool(token1, token3);
        
        // Create third pool with different token pair
        address pool3 = factory.createPool(token2, token3);
        
        // Check all pools are different
        assertTrue(pool1 != pool2, "Pools should be different");
        assertTrue(pool1 != pool3, "Pools should be different");
        assertTrue(pool2 != pool3, "Pools should be different");
        
        // Check that allPairs array is updated
        assertEq(factory.allPairs(0), pool1);
        assertEq(factory.allPairs(1), pool2);
        assertEq(factory.allPairs(2), pool3);
        
        vm.stopPrank();
    }
    
    function test_createPool_multipleUserCreatePools() public {
        vm.startPrank(OWNER);
        address token3 = tokenFactory.createToken("Test Token 3", "TT3", 1_000_000 * 10**18);
        address token4 = tokenFactory.createToken("Test Token 4", "TT4", 1_000_000 * 10**18);
        vm.stopPrank();
        
        // User1 creates a pool
        vm.prank(USER1);
        address pool1 = factory.createPool(token1, token2);
        
        // User2 creates a different pool
        vm.prank(USER2);
        address pool2 = factory.createPool(token3, token4);
        
        // Verify both pools exist
        assertEq(factory.getPool(token1, token2), pool1);
        assertEq(factory.getPool(token3, token4), pool2);
    }
    
    function test_fuzz_createPool(uint8 tokenIdA, uint8 tokenIdB) public {
        vm.assume(tokenIdA != tokenIdB);
        
        // Create a series of tokens - en commençant à partir de 1 pour éviter l'index 0
        address[] memory tokens = new address[](256);
        
        vm.startPrank(OWNER);
        for (uint8 i = 1; i < 255; i++) {  // Commencer à 1 pour s'assurer que les adresses ne sont pas nulles
            string memory name = string(abi.encodePacked("Token", i));
            string memory symbol = string(abi.encodePacked("TK", i));
            tokens[i] = tokenFactory.createToken(name, symbol, 1_000_000 * 10**18);
        }
        vm.stopPrank();
        
        // Assurons-nous que les indices sont valides et non nuls
        vm.assume(tokenIdA > 0);
        vm.assume(tokenIdB > 0);
        
        address tokenA = tokens[tokenIdA];
        address tokenB = tokens[tokenIdB];
        
        // Vérifier que les adresses sont non nulles
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        
        vm.startPrank(USER1);
        
        // Create pool with fuzzed token pair
        address poolAddress = factory.createPool(tokenA, tokenB);
        
        // Verify pool was created correctly
        assertEq(factory.getPool(tokenA, tokenB), poolAddress);
        assertEq(factory.getPool(tokenB, tokenA), poolAddress);
        
        vm.stopPrank();
    }
} 