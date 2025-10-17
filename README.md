💰 Foundry DeFi Stablecoin Project (foundry-defi-stablecoin-f23)

This repository contains a decentralized, collateral-backed stablecoin protocol built using the Foundry development framework.

🎯 Core Design and Stability Mechanisms

This system's design is based on the following principles:

Relative Stability: Pegged/Anchored -> $1.00

Chainlink Price Feed is used for accurate collateral valuation.

Functionality to exchange ETH & BTC is included (Future Feature).

Stability Mechanism (Minting): Algorithmic (Decentralized)

Minting is only possible with sufficient collateral (Coded mechanism).

Collateral: Exogenous (Crypto)

Wrapped Ether (wETH)

Wrapped Bitcoin (wBTC)

🛠 Tech Stack and Environment

Language: Solidity

Framework: Foundry (Forge & Cast)

Dependencies: Git Submodules

🚀 Quick Start

Prerequisites

Git

Foundry: Install forge and cast via the official Foundry documentation.

Installation and Setup

Clone the repository:

git clone [https://github.com/Monster-Three/foundry-defi-stablecoin-f23.git](https://github.com/Monster-Three/foundry-defi-stablecoin-f23.git)
cd foundry-defi-stablecoin-f23


Install Dependencies:

forge install


Build the project:

forge build


🧪 Testing and Coverage

Running Tests

forge test


Improvements Over Learning Material

The project maintains exceptionally high test coverage:

DSCEngine.sol Code Coverage: 98.23% (111/113) | 98.13% (105/107) | 90.91% (10/11) | 100.00% (29/29)

DecentralizedStableCoin.sol Code Coverage: 100.00% (14/14) | 100.00% (13/13) | 100.00% (4/4) | 100.00% (2/2)

Code Comments

I added extensive comments to highlight areas I struggled with and provided detailed explanations for the solutions.

📜 Project Structure

Directory/File

Description

src/

Core smart contracts.

test/

All Foundry test files.

script/

Deployment and interaction scripts.

lib/

External dependencies (e.g., Chainlink).

foundry.toml

Foundry configuration file.

Acknowledgements

Special thanks to Patrick and Gemini for providing tremendous help during this learning journey.