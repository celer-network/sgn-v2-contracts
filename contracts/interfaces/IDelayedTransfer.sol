// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

interface IDelayedTransfer {
    struct delayedTransfer {
        address receiver;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    function delayedTransfers(bytes32 transferId) external view returns (delayedTransfer memory);
}
