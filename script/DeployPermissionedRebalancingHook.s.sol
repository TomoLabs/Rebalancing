// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Uniswap v4
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

// TomoLabs
import "../src/RebalancingHook.sol";
import "../src/LiquidityVault.sol";
import "../src/HedgeVault.sol";
import "../src/YieldVault.sol";

contract DeployPermissionedRebalancing is Script {
    // Canonical CREATE2 deployer (same as Splitwise)
    address constant CREATE2_DEPLOYER =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address governance = vm.envAddress("GOVERNANCE");
        address baseToken = vm.envAddress("BASE_TOKEN");
        uint128 jitLiquidityUnits =
            uint128(vm.envUint("JIT_LIQUIDITY_UNITS"));

        vm.startBroadcast(pk);

        
        //  PERMISSIONED UNISWAP v4 POOL MANAGER
        // (same class used by Splitwise)
        
        IPoolManager poolManager =
            IPoolManager(0xA7B8e01F655C72F2fCf7b0b8F9e0633D5c86B8Dc);

        
        // DEPLOY VAULTS (REAL MAINNET CONTRACTS)
        
        LiquidityVault liquidityVault = new LiquidityVault(
            address(0), // hook set later
            governance,
            poolManager,
            baseToken,
            jitLiquidityUnits
        );

        HedgeVault hedgeVault = new HedgeVault(
            address(0),
            governance
        );

        YieldVault yieldVault = new YieldVault(
            address(0),
            governance
        );

        console.log("LiquidityVault:", address(liquidityVault));
        console.log("HedgeVault:", address(hedgeVault));
        console.log("YieldVault:", address(yieldVault));

        
        //  HOOK FLAGS
        
        uint160 flags =
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;

        
        //  MINE DETERMINISTIC HOOK ADDRESS
        
        bytes memory constructorArgs = abi.encode(
            poolManager,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );

        (address predictedHook, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(RebalancingHook).creationCode,
            constructorArgs
        );

        console.log("Predicted Hook:", predictedHook);

        
        //  DEPLOY PERMISSIONED HOOK
        
        RebalancingHook hook = new RebalancingHook{salt: salt}(
            poolManager,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );

        require(
            address(hook) == predictedHook,
            "CREATE2_MISMATCH"
        );

        console.log("RebalancingHook:", address(hook));

        
        //  WIRE HOOK → VAULTS (GOVERNANCE)
        
        liquidityVault.setHook(address(hook));
        hedgeVault.setHook(address(hook));
        yieldVault.setHook(address(hook));

        vm.stopBroadcast();
    }
}

