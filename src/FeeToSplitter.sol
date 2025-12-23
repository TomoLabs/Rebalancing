// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FeeToSplitter is ReentrancyGuard {
    struct Recipient {
        address to;
        uint96 bps;
    }

    uint96 public constant BPS = 10_000;

    address public governance;
    Recipient[] public recipients;

    event RecipientsUpdated();
    event EthSplit(uint256 totalAmount);
    event ERC20Split(address token, uint256 totalAmount);

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    constructor(address _governance) {
        governance = _governance;
    }

    
    // GOVERNANCE: SET RECIPIENTS
    
    function setRecipients(Recipient[] calldata _recipients)
        external
        onlyGovernance
    {
        delete recipients;
        uint256 total;

        for (uint256 i = 0; i < _recipients.length; i++) {
            recipients.push(_recipients[i]);
            total += _recipients[i].bps;
        }

        require(total == BPS, "INVALID_BPS");
        emit RecipientsUpdated();
    }

    
    //  SPLIT NATIVE ETH FEES
    
    function splitETH()
        external
        payable
        nonReentrant
    {
        uint256 amount = msg.value;
        require(amount > 0, "NO_ETH");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (amount * recipients[i].bps) / BPS;
            (bool ok, ) = recipients[i].to.call{value: share}("");
            require(ok, "ETH_TRANSFER_FAILED");
        }

        emit EthSplit(amount);
    }

    
    // SPLIT ERC20 FEES (v4 SAFE)
    
    function splitERC20(address token, uint256 amount)
        external
        nonReentrant
    {
        require(amount > 0, "NO_TOKENS");

        IERC20 erc20 = IERC20(token);

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (amount * recipients[i].bps) / BPS;
            erc20.transferFrom(msg.sender, recipients[i].to, share);
        }

        emit ERC20Split(token, amount);
    }

    receive() external payable {}
}

