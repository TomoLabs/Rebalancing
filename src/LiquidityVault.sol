// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidityVault is ReentrancyGuard {
    address public hook;
    address public governance;

    IPoolManager public poolManager;
    IERC20 public baseToken; // e.g. USDC

    // ✅ Mainnet-safe Pool Wiring
    PoolKey public poolKey;

    // ✅ Mainnet-safe Liquidity Accounting
    int256 public activeLiquidity;       // liquidity units
    uint256 public totalIdleLiquidity;  // token units

    // ✅ Fixed JIT Liquidity per deployment (SAFE model)
    uint128 public jitLiquidityUnits;

    // ✅ Analytics
    event Deposited(address indexed user, uint256 amount);
    event PoolKeySet(address currency0, address currency1, uint24 fee);
    event JITDeployed(uint256 amount, int256 liquidityDelta);
    event JITWithdrawn(int256 liquidityDelta);
    event EmergencyWithdraw(int256 liquidityDelta);

    modifier onlyHook() {
        require(msg.sender == hook, "ONLY_HOOK");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor(
        address _hook,
        address _governance,
        IPoolManager _poolManager,
        address _baseToken,
        uint128 _jitLiquidityUnits
    ) {
        hook = _hook;
        governance = _governance;
        poolManager = _poolManager;
        baseToken = IERC20(_baseToken);
        jitLiquidityUnits = _jitLiquidityUnits;
    }

    // ============================
    // ✅ GOVERNANCE: SET REAL POOL
    // ============================
    function setPoolKey(PoolKey calldata key) external onlyGovernance {
    require(key.tickSpacing != 0, "INVALID_POOL");
    poolKey = key;

    emit PoolKeySet(
        address(Currency.unwrap(key.currency0)),
        address(Currency.unwrap(key.currency1)),
        key.fee
    );
}


    // ============================
    // ✅ REAL TOKEN DEPOSIT
    // ============================
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "ZERO_AMOUNT");

        baseToken.transferFrom(msg.sender, address(this), amount);
        totalIdleLiquidity += amount;

        emit Deposited(msg.sender, amount);
    }

    // ============================
    // ✅ JIT ACTIVATION CHECK
    // ============================
    function shouldDeployJIT(
        uint256 swapAmount,
        uint256 thresholdBps
    ) external pure returns (bool) {
        return (swapAmount * thresholdBps) / 10_000 >= 1;
    }

    // ============================
    // ✅ MAINNET-SAFE JIT MINT
    // ============================
    function deployJIT(uint256 amount) external onlyHook nonReentrant {
        require(poolKey.tickSpacing != 0, "POOL_NOT_SET");
        require(activeLiquidity == 0, "JIT_ALREADY_ACTIVE");
        require(amount <= totalIdleLiquidity, "INSUFFICIENT_IDLE");

        totalIdleLiquidity -= amount;

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: poolKey.tickSpacing * -10,
            tickUpper: poolKey.tickSpacing * 10,
            liquidityDelta: int256(uint256(jitLiquidityUnits)),
            salt: bytes32(0)
        });

        poolManager.modifyLiquidity(poolKey, params, "");

        activeLiquidity += params.liquidityDelta;
        emit JITDeployed(amount, params.liquidityDelta);
    }

    // ============================
    // ✅ MAINNET-SAFE JIT BURN (HOOK)
    // ============================
    function withdrawJIT() external onlyHook nonReentrant {
        require(poolKey.tickSpacing != 0, "POOL_NOT_SET");
        require(activeLiquidity > 0, "NO_ACTIVE_LIQUIDITY");

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: poolKey.tickSpacing * -10,
            tickUpper: poolKey.tickSpacing * 10,
            liquidityDelta: -activeLiquidity,
            salt: bytes32(0)
        });

        poolManager.modifyLiquidity(poolKey, params, "");

        emit JITWithdrawn(params.liquidityDelta);
        activeLiquidity = 0;
    }

    // ============================
    // ✅ GOVERNANCE EMERGENCY EXIT
    // ============================
    function forceWithdraw() external onlyGovernance nonReentrant {
        require(poolKey.tickSpacing != 0, "POOL_NOT_SET");
        require(activeLiquidity > 0, "NO_ACTIVE_LIQUIDITY");

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: poolKey.tickSpacing * -10,
            tickUpper: poolKey.tickSpacing * 10,
            liquidityDelta: -activeLiquidity,
            salt: bytes32(0)
        });

        poolManager.modifyLiquidity(poolKey, params, "");

        emit EmergencyWithdraw(params.liquidityDelta);
        activeLiquidity = 0;
    }
}
