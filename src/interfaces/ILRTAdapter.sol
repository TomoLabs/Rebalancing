// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILRTAdapter {
    // ✅ MUST be payable because EzETHAdapter.deposit() is payable
    function deposit(uint256 amount) external payable;

    function withdraw(uint256 amount) external;

    function totalValue() external view returns (uint256);

    function apy() external view returns (uint256);
}
