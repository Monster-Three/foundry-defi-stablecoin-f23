# Foundry DeFi Stablecoin (F23)

This repository contains a decentralized finance (DeFi) project for creating an **overcollateralized stablecoin**. The system is built using the **Foundry** development framework for maximum speed and efficiency in smart contract development, testing, and deployment.

This project implements a core DeFi primitive where users can deposit volatile collateral in exchange for a stable token, similar to the mechanism used by protocols like MakerDAO (DAI).

## 🌟 Features

* **Overcollateralization:** The system enforces that the value of the deposited collateral always exceeds the minted stablecoin debt, ensuring the token's stability and solvency.
* **Collateral Accepted:** Supports the deposit of major assets like Wrapped Ether (**WETH**) and Wrapped Bitcoin (**WBTC**) as collateral.
* **Stablecoin Peg:** Issues a stablecoin token that is algorithmically pegged to the US Dollar (**USD**).
* **Liquidation Mechanism:** Includes a function to allow third parties (keepers) to liquidate undercollateralized positions, which is crucial for maintaining the protocol's health and peg.
* **Chainlink Integration:** Utilizes **Chainlink Data Feeds** to fetch real-time, decentralized, and tamper-proof price data for all collateral assets.
* **Modularity:** Designed to be easily forkable, allowing developers to swap out WETH & WBTC for any other basket of collateral assets.

## 🛠️ Getting Started

### Prerequisites

You will need the following tools installed on your machine:

1.  **Git**
2.  **Foundry** (`forge` and `cast` commands).
    ```bash
    curl -L [https://foundry.paradigm.xyz](https://foundry.paradigm.xyz) | bash
    foundryup
    ```
3.  A proper **RPC URL** (e.g., from Alchemy or Infura) and a **Private Key** for interacting with testnets.

### Quickstart

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Monster-Three/foundry-defi-stablecoin-f23.git](https://github.com/Monster-Three/foundry-defi-stablecoin-f23.git)
    cd foundry-defi-stablecoin-f23
    ```

2.  **Install dependencies (submodules):**
    ```bash
    forge install
    ```

3.  **Set up Environment Variables:**
    Create a file named `.env` in the root directory and add your secret variables.

    ```bash
    # Example .env content
    PRIVATE_KEY="YOUR_PRIVATE_KEY_HERE"
    SEPOLIA_RPC_URL="YOUR_SEPOLIA_RPC_URL_HERE"
    # Optional: for contract verification
    ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"
    ```

## 🚀 Usage

### 1. Start a Local Node (Anvil)

Run a local development blockchain in a separate terminal.

```bash
anvil