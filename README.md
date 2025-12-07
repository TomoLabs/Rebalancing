🧠 TomoLabs Rebalancing Hook (Uniswap v4)

TomoLabs Rebalancing Hook is a production-grade Uniswap v4 Hook that enables:

✅ Just-In-Time (JIT) liquidity deployment

✅ Post-swap liquidity withdrawal

✅ Delta-neutral hedging via HedgeVault

✅ Automated yield routing via YieldVault

✅ Protocol-level fee routing via FeeToSplitter

This hook transforms Uniswap v4 pools from static AMMs into programmable, capital-efficient financial infrastructure.

🚀 High-Level Architecture
User Swap
   │
   ▼
Uniswap v4 Pool
   │
   ▼
RebalancingHook (this repo)
   │
   ├──▶ LiquidityVault  (JIT Liquidity Engine)
   ├──▶ HedgeVault      (Delta-Neutral Hedging)
   ├──▶ YieldVault      (Restaking / LRT Yield)
   └──▶ FeeToSplitter   (Protocol Revenue Split)

🧩 Core Components
Contract	Purpose
RebalancingHook.sol	Core Uniswap v4 hook logic
LiquidityVault.sol	JIT liquidity deploy/withdraw
HedgeVault.sol	Delta-neutral risk management
YieldVault.sol	Yield compounding via LRTs
FeeToSplitter.sol	Governance-controlled fee routing
⚙️ Hook Logic Flow
✅ Before Swap

Detects large swaps using jitThresholdBps

Deploys JIT liquidity using idle capital

Narrows active tick range for max fee capture

✅ After Swap

Withdraws JIT liquidity

Sends exposure delta to HedgeVault

Sends idle capital to YieldVault for yield

Protocol fees routed via FeeToSplitter

🛠️ Tech Stack

Solidity: 0.8.24

Framework: Foundry

AMM Core: Uniswap v4 Core + Periphery

Deployment: CREATE2 via HookMiner

Standards: OpenZeppelin, Solmate

📦 Installation
git clone https://github.com/TomoLabs/Rebalancing.git
cd Rebalancing
forge install
forge build

🔐 Environment Variables

Create .env file:

PRIVATE_KEY=0xYOUR_PRIVATE_KEY
POOL_MANAGER=0xUNISWAP_V4_POOL_MANAGER
GOVERNANCE=0xYOUR_DAO_OR_MULTISIG
BASE_TOKEN=0xUSDC_OR_WETH
JIT_LIQUIDITY_UNITS=100000

🚀 Deployment (Testnet / Simulation)
forge script script/DeployRebalancingHook.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvv


✅ This will deploy:

FeeToSplitter

LiquidityVault

HedgeVault

YieldVault

RebalancingHook via CREATE2

❗ Important Note on Mainnet

At present:

✅ Uniswap v4 is not fully permissionless on Ethereum Mainnet

✅ Official PoolManager addresses are not publicly deployable yet

✅ This hook is currently deployed in:

Anvil

Local Fork

Testnets / custom v4 managers

🔒 Mainnet deployment requires Uniswap Foundation PoolManager access.

However:

✅ This code is 100% valid for Uniswap Hook Incubator review.
✅ The incubator evaluates logic correctness and architecture, not mainnet access.

✅ Compatibility With Uniswap Hook Incubator

This repo satisfies:

✅ BaseHook inheritance

✅ getHookPermissions() correctly implemented

✅ Proper use of:

beforeSwap

afterSwap

✅ Uses official:

Hooks.sol

HookMiner.sol

PoolKey, SwapParams, BeforeSwapDelta, BalanceDelta

📊 Risk Model (Summary)
Risk	Mitigation
Impermanent Loss	JIT deployment (no passive exposure)
Large Swap Slippage	Narrow tick JIT ranges
Directional Risk	Delta-neutral HedgeVault
Idle Capital Waste	YieldVault compounding
Fee Centralization	FeeToSplitter governance routing
🧪 Testing Status

✅ Compiles with Foundry

✅ Hook address mining tested

✅ Vault wiring validated

✅ CREATE2 address matching validated

🔜 Fuzz tests planned

🧑‍⚖️ Governance Model

Governance controls:

Fee splitting

Yield routing

Emergency withdrawals

Hooks remain fully non-custodial for users

🏆 Vision

TomoLabs is building a Creator-Aligned Liquidity Layer for Uniswap v4 where:

Liquidity becomes programmable

Fees become composable

Yield becomes native

Risk becomes managed on-chain

📜 License

MIT License © 2025 TomoLabs
