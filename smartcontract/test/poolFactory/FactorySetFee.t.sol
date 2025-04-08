// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/PoolFactory.sol";
import "../../src/interfaces/IPoolFactory.sol";

contract FactorySetFeeTest is Test {
    address constant OWNER = address(1);
    address constant USER1 = address(2);
    address constant USER2 = address(3);
    
    PoolFactory public factory;
    
    function setUp() public {
        vm.startPrank(OWNER);
        factory = new PoolFactory();
        vm.stopPrank();
    }
    
    function test_setFee_succeeds() public {
        uint256 initialFee = factory.fee();
        uint256 newFee = 50; // 0.5%
        
        vm.prank(OWNER);
        factory.setFee(newFee);
        
        assertEq(factory.fee(), newFee);
        assertEq(factory.getFee(), newFee);
        assertNotEq(factory.fee(), initialFee);
    }
    
    function test_setFee_succedsWithZeroFee() public {
        vm.prank(OWNER);
        factory.setFee(0);
        
        assertEq(factory.fee(), 0);
    }
    
    function test_setFee_succedsWithMaxFee() public {
        vm.prank(OWNER);
        factory.setFee(500); // 5%
        
        assertEq(factory.fee(), 500);
    }
    
    function test_setFee_revertsWhenNotOwner() public {
        vm.prank(USER1);
        bytes memory expectedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", USER1);
        vm.expectRevert(expectedError);
        factory.setFee(50);
    }
    
    function test_setFee_revertsWhenFeeTooHigh() public {
        vm.prank(OWNER);
        vm.expectRevert("Factory: fee too high");
        factory.setFee(501); // 5.01%
        
        vm.prank(OWNER);
        vm.expectRevert("Factory: fee too high");
        factory.setFee(1000); // 10%
    }
    
    function test_setFee_multipleChanges() public {
        vm.startPrank(OWNER);
        
        // First change
        factory.setFee(100); // 1%
        assertEq(factory.fee(), 100);
        
        // Second change
        factory.setFee(200); // 2%
        assertEq(factory.fee(), 200);
        
        // Third change
        factory.setFee(0); // 0%
        assertEq(factory.fee(), 0);
        
        vm.stopPrank();
    }
    
    function test_fuzz_setFee(uint256 fee) public {
        // Bound the fee to the valid range
        fee = bound(fee, 0, 500);
        
        vm.prank(OWNER);
        factory.setFee(fee);
        
        assertEq(factory.fee(), fee);
    }
} 