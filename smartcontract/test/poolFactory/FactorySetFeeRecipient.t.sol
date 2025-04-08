// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/PoolFactory.sol";
import "../../src/interfaces/IPoolFactory.sol";

contract FactorySetFeeRecipientTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    address constant NEW_RECIPIENT = address(4);
    
    PoolFactory public factory;
    
    function setUp() public {
        vm.startPrank(OWNER);
        factory = new PoolFactory();
        vm.stopPrank();
    }
    
    function test_setFeeRecipient_succeeds() public {
        address initialRecipient = factory.feeRecipient();
        assertEq(initialRecipient, OWNER, "Initial recipient should be owner");
        
        vm.prank(OWNER);
        factory.setFeeRecipient(NEW_RECIPIENT);
        
        assertEq(factory.feeRecipient(), NEW_RECIPIENT);
    }
    
    function test_setFeeRecipient_revertsWhenNotOwner() public {
        vm.prank(USER1);
        bytes memory expectedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", USER1);
        vm.expectRevert(expectedError);
        factory.setFeeRecipient(USER1);
    }
    
    function test_setFeeRecipient_revertsWhenZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert("Factory: zero address");
        factory.setFeeRecipient(address(0));
    }
    
    function test_setFeeRecipient_multipleChanges() public {
        vm.startPrank(OWNER);
        
        // First change
        factory.setFeeRecipient(USER1);
        assertEq(factory.feeRecipient(), USER1);
        
        // Second change
        factory.setFeeRecipient(USER2);
        assertEq(factory.feeRecipient(), USER2);
        
        // Third change back to owner
        factory.setFeeRecipient(OWNER);
        assertEq(factory.feeRecipient(), OWNER);
        
        vm.stopPrank();
    }
    
    function test_fuzz_setFeeRecipient(address newRecipient) public {
        vm.assume(newRecipient != address(0));
        
        vm.prank(OWNER);
        factory.setFeeRecipient(newRecipient);
        
        assertEq(factory.feeRecipient(), newRecipient);
    }
} 