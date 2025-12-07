// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ILRTAdapter.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract YieldVault is ReentrancyGuard {
    address public hook;
    address public governance;

    ILRTAdapter public activeAdapter;
    ILRTAdapter[] public adapters;

    modifier onlyHook() {
        require(msg.sender == hook, "ONLY_HOOK");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _hook, address _governance) {
        hook = _hook;
        governance = _governance;
    }

    // ============================
    // ✅ GOVERNANCE: REGISTER REAL LRTs
    // ============================
    function registerAdapter(address adapter) external onlyGovernance {
        adapters.push(ILRTAdapter(adapter));

        if (address(activeAdapter) == address(0)) {
            activeAdapter = ILRTAdapter(adapter);
        }
    }

    // ============================
    // ✅ MAINNET-SAFE EIGENLAYER REBALANCING
    // ============================
    function rebalance() external onlyHook nonReentrant {
        require(address(activeAdapter) != address(0), "NO_ACTIVE_ADAPTER");

        ILRTAdapter best = activeAdapter;
        uint256 bestApy = activeAdapter.apy();

        for (uint256 i = 0; i < adapters.length; i++) {
            uint256 candidate = adapters[i].apy();
            if (candidate > bestApy) {
                best = adapters[i];
                bestApy = candidate;
            }
        }

        if (best != activeAdapter) {
            uint256 value = activeAdapter.totalValue();
            activeAdapter.withdraw(value);
            best.deposit(value);
            activeAdapter = best;
        }
    }
}
