// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

contract TransferMultiTest is MessageSenderApp, MessageReceiverApp {
    using SafeERC20 for IERC20;

    // ========== on start chain ==========

    uint64 nonce; // required by IBridge.send

    // this func could be called by a router contract
    function startTest(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage
    ) external payable {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = "abcde";

        nonce += 1;
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount / 2,
            _dstChainId,
            nonce,
            _maxSlippage,
            message,
            MsgDataTypes.BridgeSendType.Liquidity,
            msg.value
        );

        nonce += 1;
        message = "1234567";
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount / 2,
            _dstChainId,
            nonce,
            _maxSlippage,
            message,
            MsgDataTypes.BridgeSendType.Liquidity,
            msg.value
        );
    }

    // ========== on dst chain ==========
    // do dex, send received asset to src chain via bridge
    function executeMessageWithTransfer(
        address, // _sender
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        // always return success since swap failure is already handled in-place
        return ExecutionStatus.Success;
    }
}
