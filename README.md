# Simple AMM/DEX Project (Full Stack)

This project implements a basic Automated Market Maker (AMM) / Decentralized Exchange (DEX), inspired by Uniswap V2 principles. It features Solidity smart contracts managed by Foundry, a Node.js backend API service, and a Next.js frontend DApp for interaction and visualization.

The primary goal is not just trading, but also providing a visual and educational interface to understand the core mechanics of an AMM.

## 📂 Project Structure

This monorepo contains the following main packages:

*   **`smartcontract/`**: Contains the Solidity smart contracts built with Foundry. This includes the `PoolFactory`, `Pool`, and `DexRouter` logic defining the on-chain AMM behavior. ([See Smart Contract README](smartcontract/README.md))
*   **`backend/`**: A Node.js service providing API endpoints. It interacts with the deployed smart contracts on the blockchain (e.g., Sepolia) to fetch data like pools, swaps, users, and providers, serving this information to the frontend. ([See Backend README](backend/README.md))
*   **`dapp/`**: The Next.js frontend application (built with Scaffold-ETH 2) providing the user interface. It allows users to connect wallets, claim test tokens (via the `TokenFactory`), create pools, visualize pool reserves, understand swap calculations, and trace transaction flows. ([See DApp README](dapp/README.md))

## ✨ Core Features

*   **Smart Contracts (Foundry):** Pool creation, liquidity provision, constant product swaps, smart routing (local pools or external DEX via `DexRouter`), configurable fees.
*   **Backend API (Node.js):** Serves aggregated blockchain data (pools, swaps, users) to the frontend efficiently.
*   **Frontend DApp (Next.js/Scaffold-ETH 2):** Wallet connection, test token faucet, pool creation UI, real-time pool data visualization, swap interface with formula explanation, post-swap flow visualization.

## 🛠️ Tech Stack Overview

*   **Smart Contracts:** Solidity, Foundry
*   **Backend:** Node.js, npm, (likely Express.js, Ethers.js/Viem)
*   **Frontend:** React, Next.js, TypeScript, Yarn, Wagmi, Viem, ConnectKit/RainbowKit, Tailwind CSS (via Scaffold-ETH 2)
*   **Libraries:** OpenZeppelin Contracts, forge-std

## 🚀 Getting Started

### Prerequisites

*   [Node.js](https://nodejs.org/) (LTS version recommended)
*   [Yarn](https://yarnpkg.com/) (v1 or berry, check `dapp/package.json` for specific version)
*   [Foundry](https://book.getfoundry.sh/getting-started/installation)
*   [Git](https://git-scm.com/)

## 🌐 Deployment

Refer to the README files within each package (`smartcontract/`, `backend/`, `dapp/`) for specific deployment instructions (e.g., deploying contracts with `forge script`, deploying the backend service, deploying the Next.js DApp to platforms like Vercel).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 