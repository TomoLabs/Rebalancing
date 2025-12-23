// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

// Uniswap v4
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

// TomoLabs
import "../src/RebalancingHook.sol";
import "../src/LiquidityVault.sol";
import "../src/HedgeVault.sol";
import "../src/YieldVault.sol";

contract RebalancingHookAllTest is Test {
    
     | CONSTANTS
     
    address constant GOVERNANCE = address(0x100);
    address constant BASE_TOKEN = address(0x200);
    IPoolManager constant POOL_MANAGER = IPoolManager(address(0xBEEF));

    address constant CREATE2_DEPLOYER =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

     
     
    LiquidityVault liquidityVault;
    HedgeVault hedgeVault;
    YieldVault yieldVault;
    RebalancingHook hook;

    function setUp() public {
        // Give PoolManager executable code
        vm.etch(address(POOL_MANAGER), hex"600080600a6000396000f3");

        // Mock ONLY modifyLiquidity (correct selector + return type)
        vm.mockCall(
            address(POOL_MANAGER),
            abi.encodeWithSelector(IPoolManager.modifyLiquidity.selector),
            abi.encode(BalanceDelta.wrap(0))
        );

        // CREATE2 deployer
        vm.etch(CREATE2_DEPLOYER, hex"600080600a6000396000f3");

        liquidityVault = new LiquidityVault(
            address(0),
            GOVERNANCE,
            POOL_MANAGER,
            BASE_TOKEN,
            1_000
        );

        hedgeVault = new HedgeVault(address(0), GOVERNANCE);
        yieldVault = new YieldVault(address(0), GOVERNANCE);

        // Hook flags
        uint160 flags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;

        bytes memory args = abi.encode(
            POOL_MANAGER,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );

        // Mine CREATE2 hook
        (address predicted, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(RebalancingHook).creationCode,
            args
        );

        vm.startPrank(CREATE2_DEPLOYER);
        hook = new RebalancingHook{salt: salt}(
            POOL_MANAGER,
            address(liquidityVault),
            address(hedgeVault),
            address(yieldVault)
        );
        vm.stopPrank();

        assertEq(address(hook), predicted);

        // Wire hook
        vm.prank(GOVERNANCE);
        liquidityVault.setHook(address(hook));

        vm.prank(GOVERNANCE);
        hedgeVault.setHook(address(hook));

        vm.prank(GOVERNANCE);
        yieldVault.setHook(address(hook));

        // Set PoolKey (hooks MUST be IHooks)
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0xAAA1)),
            currency1: Currency.wrap(address(0xAAA2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        vm.prank(GOVERNANCE);
        liquidityVault.setPoolKey(key);

        // CRITICAL FIX: seed idle liquidity
        vm.prank(GOVERNANCE);
        liquidityVault.__test_setIdleLiquidity(1_000);
    }

    
    function test_hook_deployment() public {
        assertTrue(address(hook) != address(0));
    }

    function test_only_hook_can_call_vaults() public {
        vm.expectRevert("ONLY_HOOK");
        liquidityVault.deployJIT(100);

        vm.expectRevert("ONLY_HOOK");
        hedgeVault.rebalance(10);

        vm.expectRevert("ONLY_HOOK");
        yieldVault.rebalance();
    }

  




    function test_no_negative_liquidity() public {
        assertGe(liquidityVault.activeLiquidity(), 0);
    }

    function test_hook_address_constant() public {
        assertEq(liquidityVault.hook(), address(hook));
    }
}

