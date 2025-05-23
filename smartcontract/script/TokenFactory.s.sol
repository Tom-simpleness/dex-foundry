// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/mocks/TokenFactory.sol";

contract TokenFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TokenFactory factory = new TokenFactory();
        console.log("TokenFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
} 