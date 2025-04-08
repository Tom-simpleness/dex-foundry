# AMM/DEX - Foundry Project

A basic Automated Market Maker (AMM) / Decentralized Exchange (DEX) implementation, inspired by Uniswap V2 principles, built using the [Foundry](https://github.com/foundry-rs/foundry) development toolkit.

This project features a `PoolFactory` for creating liquidity pools and a `DexRouter` that intelligently routes swaps.

## ✨ Features

*   **Pool Creation (`PoolFactory`):** Deploy liquidity pools for any pair of ERC20 tokens.
*   **Liquidity Provision (`Pool`):** Add or remove liquidity from pools and receive LP (Liquidity Provider) tokens.
*   **Token Swaps (`Pool`):** Swap between the two tokens within a liquidity pool based on the constant product formula (k = x * y).
*   **Smart Router (`DexRouter`):**
    *   Checks if a liquidity pool for the requested token pair exists within our system (`PoolFactory`).
    *   If a local pool exists, executes the swap directly on our `Pool` contract.
    *   If a local pool does **not** exist, forwards the swap request to an external router (e.g., Uniswap V2 Router).
    *   Charges a small configurable `forwardingFee` when routing swaps to the external DEX.
*   **Configurable Fees:**
    *   Swap fees (within local pools) are charged on trades, split between LPs and a protocol recipient.
    *   Factory owner can configure local pool fee rates and the protocol fee split.
    *   Router owner can configure the `forwardingFee` for external swaps.
*   **(Testing)** Includes a `TokenFactory` to easily deploy mock ERC20 tokens for testing purposes.

## 🛠️ Tech Stack

*   **Solidity:** ^0.8.26 (Check `foundry.toml` for the exact version)
*   **Foundry:** Fast, portable and modular toolkit for Ethereum application development used for compiling, testing, scripting, and deploying contracts.
*   **Libraries:**
    *   [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts): For standard implementations like Ownable, ERC20 interfaces, SafeERC20.
    *   [forge-std](https://github.com/foundry-rs/forge-std): Foundry's standard library for testing utilities and scripting.
    *   Uniswap V2 Interfaces (via `lib/v2-periphery` or similar): For interacting with the external router.

## 🚀 Getting Started

### Prerequisites

*   [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.
*   Git

### Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd <your-repository-directory>/smartcontract
    ```

2.  **Install dependencies:**
    Foundry manages dependencies listed in `foundry.toml`. Install them using:
    ```bash
    forge install
    ```

3.  **Environment Variables:**
    Copy the example environment file (`cp .env.example .env`) and fill in your `SEPOLIA_RPC_URL`, `PRIVATE_KEY` (starting with `0x`), and any other variables required by deployment scripts. **Warning:** Do not commit your `.env` file with your real private key.

## ⚙️ Development & Testing (with Foundry)

This project heavily relies on Foundry for its development lifecycle:

*   **Compilation:** `forge build`
*   **Testing:** `forge test` (use `-vvv` for more verbosity)
*   **Deployment & Interaction Scripts:** Scripts in the `script/` folder are run using `forge script`, typically requiring `--rpc-url` and `--broadcast`.
*   **Formatting:** `forge fmt`

Please refer to the [Foundry Book](https://book.getfoundry.sh/) for detailed command usage.

## 🌐 Deployed Contracts (Sepolia Testnet)

*   **Token Factory:**
    [`0x52d20ba31f9405db2d64c1b269937507b92b233b`](https://sepolia.etherscan.io/address/0x52d20ba31f9405db2d64c1b269937507b92b233b#writeContract)

*   **Pool Factory:**
    [`0x6d0083e9b3d75a9b3aa822502c6350b9589d5ab6`](https://sepolia.etherscan.io/address/0x6d0083e9b3d75a9b3aa822502c6350b9589d5ab6#code)

*   **Example Pool (ERCB/ERCC):**
    *   Pool Address: [`0x830dd10768dfdd87b6a1885c42b96c13f327d9d1`](https://sepolia.etherscan.io/address/0x830dd10768dfdd87b6a1885c42b96c13f327d9d1#code)
    *   ERCB Token: [`0x71686439C90B330A3cB15E77F8766675Ce8c6ee0`](https://sepolia.etherscan.io/address/0x71686439C90B330A3cB15E77F8766675Ce8c6ee0)
    *   ERCC Token: [`0x5329fdb58915b27A104eA8eCC24E3C871c6b6025`](https://sepolia.etherscan.io/address/0x5329fdb58915b27A104eA8eCC24E3C871c6b6025)


## 📄 License

This project is licensed under the MIT License.