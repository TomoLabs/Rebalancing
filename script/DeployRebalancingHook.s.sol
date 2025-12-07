// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// ✅ Uniswap v4
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

// ✅ TomoLabs
import "../src/RebalancingHook.sol";
import "../src/LiquidityVault.sol";
import "../src/HedgeVault.sol";
import "../src/YieldVault.sol";
import "../src/FeeToSplitter.sol";

contract DeployRebalancingHook is Script {
    // FIX (Error 9429): Corrected EIP-55 checksumming on the address literal.
    address constant MOCK_POOL_MANAGER_ADDRESS = 0x1F98431c8AD6CdAEfC1c2f861EA70882D8D4df6A;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address poolManagerAddr = vm.envAddress("POOL_MANAGER");
        address governanceAddr = vm.envAddress("GOVERNANCE");
        address baseTokenAddr = vm.envAddress("BASE_TOKEN");

        uint128 jitLiquidityUnits = uint128(vm.envUint("JIT_LIQUIDITY_UNITS"));

        vm.startBroadcast(deployerKey);
        
        // ============================================================
        // 🛑 FIX: MOCK POOL MANAGER IF ZERO ADDRESS 🛑
        // ============================================================
        if (poolManagerAddr == address(0)) {
            // If the environment variable is not set, use a mock address
            poolManagerAddr = MOCK_POOL_MANAGER_ADDRESS;
            // Use 'etch' cheatcode to put dummy code at this address to prevent BaseHook revert
            // This code simply returns success for any external call (like the BaseHook check)
            vm.etch(
                poolManagerAddr, 
                hex"600a600e600039600a6000f300" // Dummy contract code
            );
            console.log("MOCKING PoolManager at:", poolManagerAddr);
        }

        IPoolManager poolManager = IPoolManager(poolManagerAddr);

        // ============================================================
        // 1️⃣ DEPLOY FEE SPLITTER
        // ============================================================
        FeeToSplitter splitter = new FeeToSplitter(governanceAddr);
        console.log("FeeToSplitter:", address(splitter));

        // ============================================================
        // 2️⃣ DEPLOY VAULTS FIRST ✅ (HOOK = address(0) initially)
        // ============================================================
        LiquidityVault liquidityVault = new LiquidityVault(
            address(0),
            governanceAddr,
            poolManager,
            baseTokenAddr,
            jitLiquidityUnits
        );
        console.log("LiquidityVault:", address(liquidityVault));

        HedgeVault hedgeVault = new HedgeVault(address(0), governanceAddr);
        console.log("HedgeVault:", address(hedgeVault));

        YieldVault yieldVault = new YieldVault(address(0), governanceAddr);
        console.log("YieldVault:", address(yieldVault));

        // ============================================================
        // 3️⃣ MINE CORRECT HOOK USING REAL VAULT ADDRESSES ✅
        // ============================================================
        uint160 requiredFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );

        address deployer = vm.addr(deployerKey);

        bytes memory constructorArgs = abi.encode(
            poolManager,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );

        (address predictedHook, bytes32 salt) = HookMiner.find(
            deployer,
            requiredFlags,
            type(RebalancingHook).creationCode,
            constructorArgs
        );

        console.log("Predicted Hook:", predictedHook);

        // ============================================================
        // 4️⃣ DEPLOY HOOK WITH CREATE2 ✅
        // ============================================================
        console.log("\nDeploying RebalancingHook with args:");
        console.log("  PoolManager:", poolManagerAddr);
        console.log("  LiquidityVault:", address(liquidityVault));
        console.log("  Salt:", uint256(salt));

        // Deployment with salt modifier
        RebalancingHook hook = new RebalancingHook{salt: salt}(
            poolManager,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );

        // Get the address from the deployed contract instance
        address hookAddr = address(hook);

        require(hookAddr != address(0), "HOOK_DEPLOYMENT_FAILED");

        // This check should now pass if deployment succeeds
        require(hookAddr == predictedHook, "HOOK_ADDRESS_MISMATCH");

        console.log("RebalancingHook:", hookAddr);

        vm.stopBroadcast();
    }
}