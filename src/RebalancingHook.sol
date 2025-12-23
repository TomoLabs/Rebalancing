// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// MUST MATCH BaseHook IMPORTS EXACTLY (@uniswap)


import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {BaseHook} from "v4-periphery/utils/BaseHook.sol";


// TomoLabs Imports


import "./LiquidityVault.sol";
import "./HedgeVault.sol";
import "./YieldVault.sol";

/// @title TomoLabs Rebalancing Hook (Uniswap v4 Native)
contract RebalancingHook is BaseHook {
    LiquidityVault public liquidityVault;
    HedgeVault public hedgeVault;
    YieldVault public yieldVault;

    uint256 public jitThresholdBps = 100; // 1%

    
    constructor(
        IPoolManager _poolManager,
        address _liquidityVault,
        address _hedgeVault,
        address _yieldVault
    ) BaseHook(_poolManager) {
        liquidityVault = LiquidityVault(_liquidityVault);
        hedgeVault = HedgeVault(_hedgeVault);
        yieldVault = YieldVault(_yieldVault);
    }


    //  HOOK PERMISSIONS (SAFE)
 
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        Hooks.Permissions memory p;
        p.beforeSwap = true;
        p.afterSwap = true;
        return p;
    }

    //  INTERNAL BEFORE SWAP
   
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    )
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (sender, key, hookData);

        uint256 absAmount = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);

        if (liquidityVault.shouldDeployJIT(absAmount, jitThresholdBps)) {
            liquidityVault.deployJIT(absAmount);
        }

        return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    //  INTERNAL AFTER SWAP
    
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    )
        internal
        override
        returns (bytes4, int128)
    {
        (sender, key, params, hookData);

        hedgeVault.rebalance(delta.amount0());
        yieldVault.rebalance();
        liquidityVault.withdrawJIT();

        return (this.afterSwap.selector, 0);
    }
}


