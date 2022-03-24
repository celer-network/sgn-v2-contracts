// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../../interfaces/IBridge.sol";
import "../../interfaces/IOriginalTokenVault.sol";
import "../../interfaces/IOriginalTokenVaultV2.sol";
import "../../interfaces/IPeggedTokenBridge.sol";
import "../../interfaces/IPeggedTokenBridgeV2.sol";
import "../interfaces/IMessageReceiverApp.sol";
import "../interfaces/IMessageBus.sol";
import "../../safeguard/Ownable.sol";
import "../libraries/DataTypes.sol";

contract MessageBusReceiver is Ownable {
    mapping(bytes32 => DataTypes.TxStatus) public executedMessages;

    address public liquidityBridge; // liquidity bridge address
    address public pegBridge; // peg bridge address
    address public pegVault; // peg original vault address
    address public pegBridgeV2; // peg bridge address
    address public pegVaultV2; // peg original vault address

    event Executed(
        DataTypes.MsgType msgType,
        bytes32 msgId,
        DataTypes.TxStatus status,
        address indexed receiver,
        uint64 srcChainId,
        bytes32 srcTxHash
    );
    event NeedRetry(DataTypes.MsgType msgType, bytes32 msgId, uint64 srcChainId, bytes32 srcTxHash);

    event LiquidityBridgeUpdated(address liquidityBridge);
    event PegBridgeUpdated(address pegBridge);
    event PegVaultUpdated(address pegVault);
    event PegBridgeV2Updated(address pegBridgeV2);
    event PegVaultV2Updated(address pegVaultV2);

    constructor(
        address _liquidityBridge,
        address _pegBridge,
        address _pegVault,
        address _pegBridgeV2,
        address _pegVaultV2
    ) {
        liquidityBridge = _liquidityBridge;
        pegBridge = _pegBridge;
        pegVault = _pegVault;
        pegBridgeV2 = _pegBridgeV2;
        pegVaultV2 = _pegVaultV2;
    }

    function initReceiver(
        address _liquidityBridge,
        address _pegBridge,
        address _pegVault,
        address _pegBridgeV2,
        address _pegVaultV2
    ) internal {
        require(liquidityBridge == address(0), "liquidityBridge already set");
        liquidityBridge = _liquidityBridge;
        pegBridge = _pegBridge;
        pegVault = _pegVault;
        pegBridgeV2 = _pegBridgeV2;
        pegVaultV2 = _pegVaultV2;
    }

    // ============== functions called by executor ==============

    /**
     * @notice Execute a message with a successful transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransfer(
        bytes calldata _message,
        DataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        // For message with token transfer, message Id is computed through transfer info
        // in order to guarantee that each transfer can only be used once.
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == DataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = DataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        IBridge(liquidityBridge).verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        DataTypes.TxStatus status;
        IMessageReceiverApp.ExecuctionStatus est = executeMessageWithTransfer(_transfer, _message);
        if (est == IMessageReceiverApp.ExecuctionStatus.Success) {
            status = DataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecuctionStatus.Retry) {
            executedMessages[messageId] = DataTypes.TxStatus.Null;
            emit NeedRetry(DataTypes.MsgType.MessageWithTransfer, messageId, _transfer.srcChainId, _transfer.srcTxHash);
            return;
        } else {
            est = executeMessageWithTransferFallback(_transfer, _message);
            if (est == IMessageReceiverApp.ExecuctionStatus.Success) {
                status = DataTypes.TxStatus.Fallback;
            } else {
                status = DataTypes.TxStatus.Fail;
            }
        }
        executedMessages[messageId] = status;
        emitMessageWithTransferExecutedEvent(messageId, status, _transfer);
    }

    /**
     * @notice Execute a message with a refunded transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransferRefund(
        bytes calldata _message, // the same message associated with the original transfer
        DataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public payable {
        // similar to executeMessageWithTransfer
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == DataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = DataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransferRefund"));
        IBridge(liquidityBridge).verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        DataTypes.TxStatus status;
        IMessageReceiverApp.ExecuctionStatus est = executeMessageWithTransferRefund(_transfer, _message);
        if (est == IMessageReceiverApp.ExecuctionStatus.Success) {
            status = DataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecuctionStatus.Retry) {
            executedMessages[messageId] = DataTypes.TxStatus.Null;
            emit NeedRetry(DataTypes.MsgType.MessageWithTransfer, messageId, _transfer.srcChainId, _transfer.srcTxHash);
            return;
        } else {
            status = DataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageWithTransferExecutedEvent(messageId, status, _transfer);
    }

    /**
     * @notice Execute a message not associated with a transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessage(
        bytes calldata _message,
        DataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        // For message without associated token transfer, message Id is computed through message info,
        // in order to guarantee that each message can only be applied once
        bytes32 messageId = computeMessageOnlyId(_route, _message);
        require(executedMessages[messageId] == DataTypes.TxStatus.Null, "message already executed");
        executedMessages[messageId] = DataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Message"));
        IBridge(liquidityBridge).verifySigs(abi.encodePacked(domain, messageId), _sigs, _signers, _powers);
        DataTypes.TxStatus status;
        IMessageReceiverApp.ExecuctionStatus est = executeMessage(_route, _message);
        if (est == IMessageReceiverApp.ExecuctionStatus.Success) {
            status = DataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecuctionStatus.Retry) {
            executedMessages[messageId] = DataTypes.TxStatus.Null;
            emit NeedRetry(DataTypes.MsgType.MessageOnly, messageId, _route.srcChainId, _route.srcTxHash);
            return;
        } else {
            status = DataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageOnlyExecutedEvent(messageId, status, _route);
    }

    // ================= utils (to avoid stack too deep) =================

    function emitMessageWithTransferExecutedEvent(
        bytes32 _messageId,
        DataTypes.TxStatus _status,
        DataTypes.TransferInfo calldata _transfer
    ) private {
        emit Executed(
            DataTypes.MsgType.MessageWithTransfer,
            _messageId,
            _status,
            _transfer.receiver,
            _transfer.srcChainId,
            _transfer.srcTxHash
        );
    }

    function emitMessageOnlyExecutedEvent(
        bytes32 _messageId,
        DataTypes.TxStatus _status,
        DataTypes.RouteInfo calldata _route
    ) private {
        emit Executed(
            DataTypes.MsgType.MessageOnly,
            _messageId,
            _status,
            _route.receiver,
            _route.srcChainId,
            _route.srcTxHash
        );
    }

    function executeMessageWithTransfer(DataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecuctionStatus)
    {
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransfer.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecuctionStatus));
        }
        return IMessageReceiverApp.ExecuctionStatus.Fail;
    }

    function executeMessageWithTransferFallback(DataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecuctionStatus)
    {
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransferFallback.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecuctionStatus));
        }
        return IMessageReceiverApp.ExecuctionStatus.Fail;
    }

    function executeMessageWithTransferRefund(DataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecuctionStatus)
    {
        (bool ok, bytes memory res) = address(_transfer.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessageWithTransferRefund.selector,
                _transfer.token,
                _transfer.amount,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecuctionStatus));
        }
        return IMessageReceiverApp.ExecuctionStatus.Fail;
    }

    function verifyTransfer(DataTypes.TransferInfo calldata _transfer) private view returns (bytes32) {
        bytes32 transferId;
        address bridgeAddr;
        if (_transfer.t == DataTypes.TransferType.LqSend) {
            transferId = keccak256(
                abi.encodePacked(
                    _transfer.sender,
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount,
                    _transfer.srcChainId,
                    uint64(block.chainid),
                    _transfer.refId
                )
            );
            bridgeAddr = liquidityBridge;
            require(IBridge(bridgeAddr).transfers(transferId) == true, "bridge relay not exist");
        } else if (_transfer.t == DataTypes.TransferType.LqWithdraw) {
            transferId = keccak256(
                abi.encodePacked(
                    uint64(block.chainid),
                    _transfer.wdseq,
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount
                )
            );
            bridgeAddr = liquidityBridge;
            require(IBridge(bridgeAddr).withdraws(transferId) == true, "bridge withdraw not exist");
        } else if (_transfer.t == DataTypes.TransferType.PegMint || _transfer.t == DataTypes.TransferType.PegWithdraw) {
            transferId = keccak256(
                abi.encodePacked(
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount,
                    _transfer.sender,
                    _transfer.srcChainId,
                    _transfer.refId
                )
            );
            if (_transfer.t == DataTypes.TransferType.PegMint) {
                bridgeAddr = pegBridge;
                require(IPeggedTokenBridge(bridgeAddr).records(transferId) == true, "mint record not exist");
            } else {
                // _transfer.t == DataTypes.TransferType.PegWithdraw
                bridgeAddr = pegVault;
                require(IOriginalTokenVault(bridgeAddr).records(transferId) == true, "withdraw record not exist");
            }
        } else if (
            _transfer.t == DataTypes.TransferType.PegMintV2 || _transfer.t == DataTypes.TransferType.PegWithdrawV2
        ) {
            if (_transfer.t == DataTypes.TransferType.PegMintV2) {
                bridgeAddr = pegBridgeV2;
            } else {
                // DataTypes.TransferType.PegWithdrawV2
                bridgeAddr = pegVaultV2;
            }
            transferId = keccak256(
                abi.encodePacked(
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount,
                    _transfer.sender,
                    _transfer.srcChainId,
                    _transfer.refId,
                    bridgeAddr
                )
            );
            if (_transfer.t == DataTypes.TransferType.PegMintV2) {
                require(IPeggedTokenBridgeV2(bridgeAddr).records(transferId) == true, "mint record not exist");
            } else {
                // DataTypes.TransferType.PegWithdrawV2
                require(IOriginalTokenVaultV2(bridgeAddr).records(transferId) == true, "withdraw record not exist");
            }
        }
        return keccak256(abi.encodePacked(DataTypes.MsgType.MessageWithTransfer, bridgeAddr, transferId));
    }

    function computeMessageOnlyId(DataTypes.RouteInfo calldata _route, bytes calldata _message)
        private
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    DataTypes.MsgType.MessageOnly,
                    _route.sender,
                    _route.receiver,
                    _route.srcChainId,
                    _route.srcTxHash,
                    uint64(block.chainid),
                    _message
                )
            );
    }

    function executeMessage(DataTypes.RouteInfo calldata _route, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecuctionStatus)
    {
        (bool ok, bytes memory res) = address(_route.receiver).call{value: msg.value}(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessage.selector,
                _route.sender,
                _route.srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecuctionStatus));
        }
        return IMessageReceiverApp.ExecuctionStatus.Fail;
    }

    // ================= helper (non-critical) functions =====================

    /**
     * @notice convenience function that aggregates two refund calls into one to save user transaction fees
     * @dev caller must get the required input params to each call first by querying SGN gateway and SGN node
     * @param _srcBridgeType the type of the bridge that is used in the original sendMessageWithTransfer call
     * @param _bridgeRefund call params to LiquidityBridge.withdraw(), PegBridge.Mint(),
     *                      PegVault.Withdraw(), PegBridgeV2.Mint(), or PegVaultV2.Withdraw()
     * @param _msgRefund call params to MessageBus.executeMessageWithTransferRefund()
     */
    function refund(
        DataTypes.BridgeType _srcBridgeType,
        DataTypes.BridgeRefundParams calldata _bridgeRefund,
        DataTypes.MsgRefundParams calldata _msgRefund
    ) external {
        if (_srcBridgeType == DataTypes.BridgeType.Liquidity) {
            IBridge(liquidityBridge).withdraw(
                _bridgeRefund.request,
                _bridgeRefund.sigs,
                _bridgeRefund.signers,
                _bridgeRefund.powers
            );
        } else if (_srcBridgeType == DataTypes.BridgeType.PegDeposit) {
            IOriginalTokenVault(pegVault).withdraw(
                _bridgeRefund.request,
                _bridgeRefund.sigs,
                _bridgeRefund.signers,
                _bridgeRefund.powers
            );
        } else if (_srcBridgeType == DataTypes.BridgeType.PegBurn) {
            IPeggedTokenBridge(pegBridge).mint(
                _bridgeRefund.request,
                _bridgeRefund.sigs,
                _bridgeRefund.signers,
                _bridgeRefund.powers
            );
        } else if (_srcBridgeType == DataTypes.BridgeType.PegDepositV2) {
            IOriginalTokenVaultV2(pegVaultV2).withdraw(
                _bridgeRefund.request,
                _bridgeRefund.sigs,
                _bridgeRefund.signers,
                _bridgeRefund.powers
            );
        } else if (_srcBridgeType == DataTypes.BridgeType.PegBurnV2) {
            IPeggedTokenBridgeV2(pegBridgeV2).mint(
                _bridgeRefund.request,
                _bridgeRefund.sigs,
                _bridgeRefund.signers,
                _bridgeRefund.powers
            );
        }
        executeMessageWithTransferRefund(
            _msgRefund.message,
            _msgRefund.transfer,
            _msgRefund.sigs,
            _msgRefund.signers,
            _msgRefund.powers
        );
    }

    // ================= contract addr config =================

    function setLiquidityBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        liquidityBridge = _addr;
        emit LiquidityBridgeUpdated(liquidityBridge);
    }

    function setPegBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        pegBridge = _addr;
        emit PegBridgeUpdated(pegBridge);
    }

    function setPegVault(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        pegVault = _addr;
        emit PegVaultUpdated(pegVault);
    }

    function setPegBridgeV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        pegBridgeV2 = _addr;
        emit PegBridgeV2Updated(pegBridgeV2);
    }

    function setPegVaultV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        pegVaultV2 = _addr;
        emit PegVaultV2Updated(pegVaultV2);
    }
}
