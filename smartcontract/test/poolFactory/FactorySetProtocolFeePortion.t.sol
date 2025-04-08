// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/PoolFactory.sol";
import "../../src/interfaces/IPoolFactory.sol";

contract FactorySetProtocolFeePortionTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    
    PoolFactory public factory;
    
    function setUp() public {
        vm.startPrank(OWNER);
        factory = new PoolFactory();
        vm.stopPrank();
    }
    
    function test_setProtocolFeePortion_succeeds() public {
        uint256 initialPortion = factory.protocolFeePortion();
        assertEq(initialPortion, 5000, "Initial protocol fee portion should be 50%");
        
        uint256 newPortion = 3000; // 30%
        
        vm.prank(OWNER);
        factory.setProtocolFeePortion(newPortion);
        
        assertEq(factory.protocolFeePortion(), newPortion);
        assertNotEq(factory.protocolFeePortion(), initialPortion);
    }
    
    function test_setProtocolFeePortion_succeedsWithZeroPortion() public {
        vm.prank(OWNER);
        factory.setProtocolFeePortion(0);
        
        assertEq(factory.protocolFeePortion(), 0, "Protocol fee portion should be 0% (all to LPs)");
    }
    
    function test_setProtocolFeePortion_succeedsWithMaxPortion() public {
        vm.prank(OWNER);
        factory.setProtocolFeePortion(10000); // 100%
        
        assertEq(factory.protocolFeePortion(), 10000, "Protocol fee portion should be 100% (all to protocol)");
    }
    
    function test_setProtocolFeePortion_revertsWhenNotOwner() public {
        vm.prank(USER1);
        bytes memory expectedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", USER1);
        vm.expectRevert(expectedError);
        factory.setProtocolFeePortion(5000);
    }
    
    function test_setProtocolFeePortion_revertsWhenTooHigh() public {
        vm.prank(OWNER);
        vm.expectRevert("Factory: invalid protocol fee portion");
        factory.setProtocolFeePortion(10001); // 100.01%
        
        vm.prank(OWNER);
        vm.expectRevert("Factory: invalid protocol fee portion");
        factory.setProtocolFeePortion(20000); // 200%
    }
    
    function test_setProtocolFeePortion_multipleChanges() public {
        vm.startPrank(OWNER);
        
        // First change
        factory.setProtocolFeePortion(2000); // 20%
        assertEq(factory.protocolFeePortion(), 2000);
        
        // Second change
        factory.setProtocolFeePortion(7500); // 75%
        assertEq(factory.protocolFeePortion(), 7500);
        
        // Third change
        factory.setProtocolFeePortion(0); // 0%
        assertEq(factory.protocolFeePortion(), 0);
        
        // Fourth change
        factory.setProtocolFeePortion(10000); // 100%
        assertEq(factory.protocolFeePortion(), 10000);
        
        vm.stopPrank();
    }
    
    function test_fuzz_setProtocolFeePortion(uint256 portion) public {
        // Bound the portion to the valid range
        portion = bound(portion, 0, 10000);
        
        vm.prank(OWNER);
        factory.setProtocolFeePortion(portion);
        
        assertEq(factory.protocolFeePortion(), portion);
    }
} 