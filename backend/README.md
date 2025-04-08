# DEX Backend Service

This Node.js backend service supports the DEX frontend application by providing necessary API endpoints and interacting with the deployed smart contracts on the blockchain.

## ✨ Features

*   **API Endpoints:** Provides data to the frontend regarding DEX pools, swap history, users, and liquidity providers.
*   **Blockchain Interaction:** Connects to an Ethereum node to fetch real-time data from the deployed smart contracts.
*   **Integrated Testing:** Development server automatically runs endpoint tests upon startup.

## 🛠️ Tech Stack

*   **Node.js:** JavaScript runtime environment.
*   **npm:** Package manager for Node.js.
*   **Express.js:** Web framework for building the API (or similar like Koa, Fastify).
*   **Ethers.js / Viem:** Libraries for interacting with the Ethereum blockchain.
*   **Testing Framework:** Integrated into the `npm run dev` script (e.g., Jest, Mocha, Supertest).

## 🔌 API Endpoints

The following endpoints are available (base URL: `http://localhost:<PORT>`):

*   `GET /`: API overview and available endpoints list.
*   `GET /api/test`: Tests the backend's connection to the configured blockchain node.
*   `GET /api/pools`: Retrieves a list of liquidity pools created by the factory.
*   `GET /api/swaps`: Fetches a history of swap events from the pools.
*   `GET /api/users`: Retrieves a list of unique users who have interacted (e.g., swapped).
*   `GET /api/providers`: Retrieves a list of unique liquidity providers.


## 🚀 Getting Started

### Prerequisites

*   [Node.js](https://nodejs.org/) (LTS version recommended) and npm.
*   Git.

### Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd <your-repository-directory>/backend
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Environment Variables:**
    *   Create a `.env` file in the `backend` directory (you might want to copy from a `.env.example` if one exists).
    *   Configure necessary environment variables, which likely include:
        *   `PORT`: The port the server will run on (e.g., 3000).
        *   `RPC_URL`: The RPC endpoint URL for connecting to the blockchain (e.g., Sepolia RPC URL).
        *   `POOL_FACTORY_ADDRESS`: Deployed address of your `PoolFactory` contract.
        *   `DEX_ROUTER_ADDRESS`: Deployed address of your `DexRouter` contract (if the backend interacts with it).
        *   Any other API keys or configuration needed.

## ⚙️ Usage

*   **Development:**
    Starts the server with automatic reloading (e.g., using `nodemon`) and runs tests after startup.
    ```bash
    npm run dev
    ```
    The API will typically be available at `http://localhost:<PORT>` (e.g., `http://localhost:3000`).

*   **Testing:**
    Tests are run automatically with `npm run dev`. If there's a separate test command:
    ```bash
    # Example: npm test
    ```
    *(Adjust the command based on your package.json)*

*   **Production Build:**
    If your project requires a build step (e.g., for TypeScript):
    ```bash
    # Example: npm run build
    ```
    *(Adjust the command based on your package.json)*

*   **Start in Production:**
    Runs the compiled/built application.
    ```bash
    npm start
    ```

## 📄 License

This project is licensed under the MIT License. 