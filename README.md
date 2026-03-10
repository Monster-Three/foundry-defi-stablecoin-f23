# Foundry DeFi Stablecoin (F23)

一个使用 **Foundry** 框架实现的**去中心化、超额抵押型稳定币协议**，灵感来源于 MakerDAO 的 DAI 系统。

用户可以将 **WETH** 或 **WBTC** 作为抵押品存入协议，铸造出与美元 **1:1** 锚定的稳定币 **DSC**（Decentralized StableCoin）。协议通过 **Chainlink** 价格预言机获取实时价格，并支持清算机制来维持系统整体健康。

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-black?logo=solidity)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 项目特点

- **超额抵押**：所有铸币行为必须有 ≥ 150%（可配置）的抵押率
- **支持的抵押品**：WETH、WBTC（可扩展）
- **价格预言机**：使用 Chainlink Data Feeds 确保去中心化定价
- **清算机制**：当健康因子 < 1 时，任何人可触发清算并获得奖励
- **模块化设计**：核心逻辑在 `DSCEngine`，代币合约 `DecentralizedStableCoin` 独立
- **高性能测试**：使用 Foundry 的 fuzz/invariant 测试框架
- **本地开发友好**：Anvil + 脚本一键部署 & 交互

## 技术栈

- Solidity ^0.8.20
- Foundry (forge, cast, anvil)
- Chainlink 接口
- OpenZeppelin Contracts (ERC20 等)
- 依赖通过 `forge install` 管理

## 快速开始

### 环境要求

- [Foundry](https://getfoundry.sh/) 已安装
- git
- (可选) .env 文件用于 Sepolia 测试网部署

### 安装步骤

```bash
# 克隆仓库
git clone https://github.com/Monster-Three/foundry-defi-stablecoin-f23.git
cd foundry-defi-stablecoin-f23

# 安装依赖（OpenZeppelin、Chainlink 等）
forge install

# (可选) 创建 .env 文件用于 Sepolia 部署/验证
cp .env.example .env
# 然后编辑 .env 填入你的 PRIVATE_KEY、SEPOLIA_RPC_URL、ETHERSCAN_API_KEY
```

### 本地开发 & 测试

```bash
# 启动本地节点（Anvil）
anvil

# 在新终端运行全部测试（含 fuzz & invariant）
forge test

# 运行特定测试文件
forge test --match-contract DSCEngineTest

# 查看 gas 报告
forge test --gas-report

# 格式化代码
forge fmt
```

### 部署（本地或 Sepolia）

```bash
# 本地模拟部署
forge script script/DeployDSC.s.sol --broadcast --fork-url http://localhost:8545

# 部署到 Sepolia（需配置 .env）
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## 项目结构

```
foundry-defi-stablecoin-f23/
├── lib/                # forge 依赖库 (openzeppelin, chainlink 等)
├── script/             # 部署 & 交互脚本
│   └── DeployDSC.s.sol
├── src/                # 核心合约
│   ├── DecentralizedStableCoin.sol     # ERC20 稳定币实现
│   └── DSCEngine.sol                   # 核心引擎（存款、铸币、赎回、清算）
├── test/               # 测试文件
│   ├── handler/        # 用于 invariant 测试的 handler
│   └── fuzz/           # fuzz 测试用例
├── foundry.toml
└── .env.example
```

## 安全 & 注意事项

- **仅用于学习和实验**：本项目主要为教育目的，未经过任何正式审计。
- **价格操纵风险**：依赖 Chainlink 预言机，仍存在延迟/操纵的理论风险。
- **清算激励**：当前清算奖励设置为固定百分比，可根据实际需求调整。
- 生产环境使用前必须进行完整的安全审计。

欢迎提交 PR、issue 或 fork 改进！

## 致谢 & 灵感来源

- Cyfrin Updraft 课程 — Patrick Collins 的 Foundry 高级教程
- MakerDAO 的 DAI 机制设计
- Chainlink 社区提供的免费预言机服务

Happy hacking! 🚀