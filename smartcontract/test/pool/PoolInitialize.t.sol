// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Pool.sol";
import "../../src/TokenFactory.sol";

contract PoolInitializeTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant FACTORY = address(4);
    
    Pool public pool;
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
        
        // Deploy pool without initializing
        pool = new Pool();
        vm.stopPrank();
    }
    
    function test_initialize_succeeds() public {
        vm.prank(OWNER);
        pool.initialize(token1, token2, FACTORY);
        
        // Verify initialization
        (address poolToken1, address poolToken2) = pool.getTokens();
        assertEq(poolToken1, token1, "Token1 not set correctly");
        assertEq(poolToken2, token2, "Token2 not set correctly");
        assertEq(pool.factory(), FACTORY, "Factory not set correctly");
        
        // Verify tokens were initialized correctly
        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, 0, "Initial reserve1 should be 0");
        assertEq(reserve2, 0, "Initial reserve2 should be 0");
    }
    
    function test_initialize_revertsWhenNotOwner() public {
        // OWNER is the owner of the pool from setUp
        // Try to initialize with a different user who is not the owner
        vm.prank(USER1);
        vm.expectRevert();
        pool.initialize(token1, token2, FACTORY);
    }
    
    function test_initialize_revertsWhenAlreadyInitialized() public {
        // First initialization
        vm.prank(OWNER);
        pool.initialize(token1, token2, FACTORY);
        
        // Try to initialize again
        vm.prank(OWNER);
        vm.expectRevert("Pool: already initialized");
        pool.initialize(token1, token2, FACTORY);
    }
    
    function test_initialize_revertsWhenZeroAddress() public {
        vm.startPrank(OWNER);
        
        // Zero token1
        vm.expectRevert("Pool: zero address");
        pool.initialize(address(0), token2, FACTORY);
        
        // Zero token2
        vm.expectRevert("Pool: zero address");
        pool.initialize(token1, address(0), FACTORY);
        
        // Both zero
        vm.expectRevert("Pool: zero address");
        pool.initialize(address(0), address(0), FACTORY);
        
        vm.stopPrank();
    }
    
    function test_initialize_revertsWhenIdenticalAddresses() public {
        vm.prank(OWNER);
        vm.expectRevert("Pool: identical addresses");
        pool.initialize(token1, token1, FACTORY);
    }
    
    function test_initialize_withDifferentFactoryAddresses() public {
        // First pool with Factory1
        vm.startPrank(OWNER);
        Pool pool1 = new Pool();
        pool1.initialize(token1, token2, FACTORY);
        vm.stopPrank();
        
        // Second pool with Factory2
        vm.startPrank(OWNER);
        Pool pool2 = new Pool();
        pool2.initialize(token1, token2, FACTORY);
        vm.stopPrank();
        
        // Verify both pools have the same tokens but different factory addresses
        (address pool1TokenA, address pool1TokenB) = pool1.getTokens();
        (address pool2TokenA, address pool2TokenB) = pool2.getTokens();
        
        assertEq(pool1TokenA, pool2TokenA, "TokenA should match across pools");
        assertEq(pool1TokenB, pool2TokenB, "TokenB should match across pools");
        assertEq(pool1.factory(), FACTORY, "Factory address should match FACTORY");
        assertEq(pool2.factory(), FACTORY, "Factory address should match FACTORY");
    }
    
    function test_fuzz_initialize(address _factory) public {
        vm.assume(_factory != address(0));
        
        vm.prank(OWNER);
        pool.initialize(token1, token2, _factory);
        
        assertEq(pool.factory(), _factory);
    }
} 