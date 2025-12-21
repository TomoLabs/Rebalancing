// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HedgeVault is ReentrancyGuard {
    address public hook;
    address public governance;

    // ✅ Track total open hedge exposure (base asset units)
    int256 public netOpenInterest;

    // ✅ Emergency pause
    bool public paused;

    modifier onlyHook() {
        require(msg.sender == hook, "ONLY_HOOK");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    modifier notPaused() {
        require(!paused, "HEDGING_PAUSED");
        _;
    }

    constructor(address _hook, address _governance) {
        hook = _hook;
        governance = _governance;
    }

    // ============================
    // ✅ CORE HEDGE REBALANCING
    // ============================
    function rebalance(int256 delta)
        external
        onlyHook
        notPaused
        nonReentrant
    {
        if (delta > 0) {
            _openShort(uint256(delta));
            netOpenInterest -= delta; // short increases negative exposure
        } else if (delta < 0) {
            _closeShort(uint256(-delta));
            netOpenInterest += (-delta);
        }
    }

    // ============================
    // ✅ OPEN SHORT (GMX / PERP ADAPTER GOES HERE)
    // ============================
    function _openShort(uint256 amount) internal {
        // ✅ TODO: call GMX / Synthetix open short
        // Example:
        // perpRouter.openShort(amount);
    }

    // ============================
    // ✅ CLOSE SHORT
    // ============================
    function _closeShort(uint256 amount) internal {
        // ✅ TODO: call GMX / Synthetix close short
        // Example:
        // perpRouter.closeShort(amount);
    }

    // ============================
    // ✅ EMERGENCY CONTROLS
    // ============================
    function pause() external onlyGovernance {
        paused = true;
    }

    function unpause() external onlyGovernance {
        paused = false;
    }

    function forceCloseAll() external onlyGovernance nonReentrant {
        if (netOpenInterest < 0) {
            _closeShort(uint256(-netOpenInterest));
            netOpenInterest = 0;
        }
    }

    function setHook(address _hook) external onlyGovernance {
    require(_hook != address(0), "INVALID_HOOK");
    hook = _hook;
}

}
