// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Assuming ILRTAdapter.sol is updated to define deposit as payable:
// function deposit(uint256 amount) external payable returns (uint256);
import "../interfaces/ILRTAdapter.sol"; 
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IezETH {
    // The deposit function must be payable in the interface as well
    function deposit() external payable; 
    function withdraw(uint256 shares) external;
    function balanceOf(address user) external view returns (uint256);
}

contract EzETHAdapter is ILRTAdapter, ReentrancyGuard {
    IezETH public ezETH;
    address public vault; // YieldVault

    modifier onlyVault() {
        require(msg.sender == vault, "ONLY_VAULT");
        _;
    }

    constructor(address _ezETH, address _vault) {
        ezETH = IezETH(_ezETH);
        vault = _vault;
    }

    // ============================
    // ✅ SAFE ETH DEPOSIT
    // ============================
    // NOTE: If ILRTAdapter.deposit had (uint256 amount) as a parameter, 
    // we must keep it for the override, but we should use msg.value for the call.
    // However, since we rely on msg.value, let's simplify the function signature
    // to match the common pattern for staking ETH.
    // If the interface requires (uint256 amount), keep the parameter and use msg.value.
    
    // Assuming ILRTAdapter.deposit is function deposit(uint256 amount) external payable override...
    function deposit(uint256 amount) external
        payable
        override
        onlyVault
        nonReentrant
    {
        // Require the passed 'amount' parameter (for logging/consistency) to match the sent ETH.
        require(msg.value == amount, "INVALID_ETH_AMOUNT"); 
        
        // Use msg.value for the external call, as it is the value sent with this transaction.
        ezETH.deposit{value: msg.value}(); 
    }

    // ============================
    // ✅ CONSISTENT WITH YieldVault (WITHDRAW BY SHARES)
    // ============================
    function withdraw(uint256 shares)
        external
        override
        onlyVault
        nonReentrant
    {
        ezETH.withdraw(shares);
    }

    // ============================
    // ✅ TOTAL VALUE IN SHARES
    // ============================
    function totalValue() external view override returns (uint256) {
        // ezETH.balanceOf returns the amount of ezETH shares held by this contract.
        return ezETH.balanceOf(address(this));
    }

    // ============================
    // ✅ APY IN BPS
    // ============================
    function apy() external pure override returns (uint256) {
        return 850; // 8.5%, wire oracle later
    }

    // ============================
    // ✅ FALLBACK RECEIVE
    // ============================
    // This allows the contract to receive ETH directly (e.g., from ezETH withdrawal)
    receive() external payable {}
}