// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol"; // Import console for logging

// Minimal ERC20 interface needed for approve
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ApproveTokens is Script {
    // --- Configuration ---
    // Addresses from approve.sh
    address constant TOKEN_A_ADDRESS = 0x5329fdb58915b27A104eA8eCC24E3C871c6b6025;
    address constant TOKEN_B_ADDRESS = 0x71686439C90B330A3cB15E77F8766675Ce8c6ee0;
    address constant SPENDER_ADDRESS = 0x830dD10768DFDd87B6a1885C42b96c13f327d9D1;

    // Amounts from approve.sh (using underscores for readability)
    // Adjust decimals if necessary (e.g., use 10**tokenDecimals)
    uint256 constant TOKEN_A_AMOUNT = 5_000 * 1 ether; // 5000 tokens assuming 18 decimals
    uint256 constant TOKEN_B_AMOUNT = 10_000 * 1 ether; // 10000 tokens assuming 18 decimals

    function run() external {
        // Load private key from .env file (must not have 0x prefix in .env)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY environment variable not set or invalid");

        // Get RPC URL from FOUNDRY_ETH_RPC_URL, SEPOLIA_RPC_URL or command line --rpc-url
        string memory rpcURL = vm.rpcUrl("sepolia"); // Use alias "sepolia" to get the specific RPC URL if configured
        console.log("Using RPC URL:", rpcURL);

        // Start broadcasting transactions signed with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Approve Token A
        console.log(
            "Approving Token A (%s) for spender %s with amount %s...",
            TOKEN_A_ADDRESS,
            SPENDER_ADDRESS,
            TOKEN_A_AMOUNT
        );
        IERC20(TOKEN_A_ADDRESS).approve(SPENDER_ADDRESS, TOKEN_A_AMOUNT);
        console.log("Approved Token A successfully.");

        // Approve Token B
        console.log(
            "Approving Token B (%s) for spender %s with amount %s...",
            TOKEN_B_ADDRESS,
            SPENDER_ADDRESS,
            TOKEN_B_AMOUNT
        );
        IERC20(TOKEN_B_ADDRESS).approve(SPENDER_ADDRESS, TOKEN_B_AMOUNT);
        console.log("Approved Token B successfully.");

        // Stop broadcasting
        vm.stopBroadcast();

        console.log("\nToken approvals finished successfully!");
    }
} 