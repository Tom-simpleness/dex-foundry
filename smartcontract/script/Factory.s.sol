// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Factory.sol";

contract FactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint256 fee = vm.envUint("FEE_RATE"); // en points de base (30 = 0.3%)
        
        vm.startBroadcast(deployerPrivateKey);

        // Déployer Factory
        Factory factory = new Factory();
        
        // Configurer les frais et le destinataire des frais
        factory.setFee(fee);
        factory.setFeeRecipient(feeRecipient);
        
        console.log("Factory deployed at:", address(factory));
        console.log("Fee rate set to:", fee);
        console.log("Fee recipient set to:", feeRecipient);

        vm.stopBroadcast();
    }
} 