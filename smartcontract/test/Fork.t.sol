// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";


contract ForkTest is Test {
    address uniswapV2Factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    function setUp() public {
        string memory rpcUrl = vm.rpcUrl("mainnet");
        vm.createSelectFork(rpcUrl,22076386);
    }

    function test_Fork() public {
        (bool success, bytes memory data) = uniswapV2Factory.call(abi.encodeWithSignature("allPairsLength()"));
        console.logBytes(data);
    }
}
