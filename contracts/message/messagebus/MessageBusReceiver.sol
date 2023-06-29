// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../libraries/MsgDataTypes.sol";
import "../interfaces/IMessageReceiverApp.sol";
import "../../interfaces/IBridge.sol";
import "../../interfaces/IOriginalTokenVault.sol";
import "../../interfaces/IOriginalTokenVaultV2.sol";
import "../../interfaces/IPeggedTokenBridge.sol";
import "../../interfaces/IPeggedTokenBridgeV2.sol";
import "../../interfaces/IDelayedTransfer.sol";
import "../../safeguard/Ownable.sol";
import "../../libraries/Utils.sol";

contract MessageBusReceiver is Ownable {
    mapping(bytes32 => MsgDataTypes.TxStatus) public executedMessages;

    address public liquidityBridge; // liquidity bridge address
    address public pegBridge; // peg bridge address
    address public pegVault; // peg original vault address
    address public pegBridgeV2; // peg bridge address
    address public pegVaultV2; // peg original vault address

    // minimum amount of gas needed by this contract before it tries to
    // deliver a message to the target contract.
    uint256 public preExecuteMessageGasUsage;

    event Executed(
        MsgDataTypes.MsgType msgType,
        bytes32 msgId,
        MsgDataTypes.TxStatus status,
        address indexed receiver,
        uint64 srcChainId,
        bytes32 srcTxHash
    );
    event NeedRetry(MsgDataTypes.MsgType msgType, bytes32 msgId, uint64 srcChainId, bytes32 srcTxHash);
    event CallReverted(string reason); // help debug

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
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public payable {
        // For message with token transfer, message Id is computed through transfer info
        // in order to guarantee that each transfer can only be used once.
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        IBridge(liquidityBridge).verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessageWithTransfer(_transfer, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(
                MsgDataTypes.MsgType.MessageWithTransfer,
                messageId,
                _transfer.srcChainId,
                _transfer.srcTxHash
            );
            return;
        } else {
            est = executeMessageWithTransferFallback(_transfer, _message);
            if (est == IMessageReceiverApp.ExecutionStatus.Success) {
                status = MsgDataTypes.TxStatus.Fallback;
            } else {
                status = MsgDataTypes.TxStatus.Fail;
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
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) public payable {
        // similar to executeMessageWithTransfer
        bytes32 messageId = verifyTransfer(_transfer);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "transfer already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransferRefund"));
        IBridge(liquidityBridge).verifySigs(
            abi.encodePacked(domain, messageId, _message, _transfer.srcTxHash),
            _sigs,
            _signers,
            _powers
        );
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessageWithTransferRefund(_transfer, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(
                MsgDataTypes.MsgType.MessageWithTransfer,
                messageId,
                _transfer.srcChainId,
                _transfer.srcTxHash
            );
            return;
        } else {
            status = MsgDataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageWithTransferExecutedEvent(messageId, status, _transfer);
    }

    /**
     * @notice Execute a message not associated with a transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _route The info about the sender and the receiver.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        MsgDataTypes.Route memory route = getRouteInfo(_route);
        executeMessage(_message, route, _sigs, _signers, _powers, "Message");
    }

    // execute message from non-evm chain with bytes for sender address,
    // otherwise same as above.
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo2 calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        MsgDataTypes.Route memory route = getRouteInfo(_route);
        executeMessage(_message, route, _sigs, _signers, _powers, "Message2");
    }

    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.Route memory _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        string memory domainName
    ) private {
        // For message without associated token transfer, message Id is computed through message info,
        // in order to guarantee that each message can only be applied once
        bytes32 messageId = computeMessageOnlyId(_route, _message);
        require(executedMessages[messageId] == MsgDataTypes.TxStatus.Null, "message already executed");
        executedMessages[messageId] = MsgDataTypes.TxStatus.Pending;

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), domainName));
        IBridge(liquidityBridge).verifySigs(abi.encodePacked(domain, messageId), _sigs, _signers, _powers);
        MsgDataTypes.TxStatus status;
        IMessageReceiverApp.ExecutionStatus est = executeMessage(_route, _message);
        if (est == IMessageReceiverApp.ExecutionStatus.Success) {
            status = MsgDataTypes.TxStatus.Success;
        } else if (est == IMessageReceiverApp.ExecutionStatus.Retry) {
            executedMessages[messageId] = MsgDataTypes.TxStatus.Null;
            emit NeedRetry(MsgDataTypes.MsgType.MessageOnly, messageId, _route.srcChainId, _route.srcTxHash);
            return;
        } else {
            status = MsgDataTypes.TxStatus.Fail;
        }
        executedMessages[messageId] = status;
        emitMessageOnlyExecutedEvent(messageId, status, _route);
    }

    // ================= utils (to avoid stack too deep) =================

    function emitMessageWithTransferExecutedEvent(
        bytes32 _messageId,
        MsgDataTypes.TxStatus _status,
        MsgDataTypes.TransferInfo calldata _transfer
    ) private {
        emit Executed(
            MsgDataTypes.MsgType.MessageWithTransfer,
            _messageId,
            _status,
            _transfer.receiver,
            _transfer.srcChainId,
            _transfer.srcTxHash
        );
    }

    function emitMessageOnlyExecutedEvent(
        bytes32 _messageId,
        MsgDataTypes.TxStatus _status,
        MsgDataTypes.Route memory _route
    ) private {
        emit Executed(
            MsgDataTypes.MsgType.MessageOnly,
            _messageId,
            _status,
            _route.receiver,
            _route.srcChainId,
            _route.srcTxHash
        );
    }

    function executeMessageWithTransfer(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
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
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function executeMessageWithTransferFallback(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
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
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function executeMessageWithTransferRefund(MsgDataTypes.TransferInfo calldata _transfer, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
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
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function verifyTransfer(MsgDataTypes.TransferInfo calldata _transfer) private view returns (bytes32) {
        bytes32 transferId;
        address bridgeAddr;
        MsgDataTypes.TransferType t = _transfer.t;
        if (t == MsgDataTypes.TransferType.LqRelay) {
            bridgeAddr = liquidityBridge;
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
            require(IBridge(bridgeAddr).transfers(transferId) == true, "relay not exist");
        } else if (t == MsgDataTypes.TransferType.LqWithdraw) {
            bridgeAddr = liquidityBridge;
            transferId = keccak256(
                abi.encodePacked(
                    uint64(block.chainid),
                    _transfer.wdseq,
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount
                )
            );
            require(IBridge(bridgeAddr).withdraws(transferId) == true, "withdraw not exist");
        } else {
            if (t == MsgDataTypes.TransferType.PegMint || t == MsgDataTypes.TransferType.PegWithdraw) {
                bridgeAddr = (t == MsgDataTypes.TransferType.PegMint) ? pegBridge : pegVault;
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
            } else {
                bridgeAddr = (t == MsgDataTypes.TransferType.PegV2Mint) ? pegBridgeV2 : pegVaultV2;
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
            }
            // function is same for peg, peg2, vault, vault2
            require(IPeggedTokenBridge(bridgeAddr).records(transferId) == true, "record not exist");
        }
        require(IDelayedTransfer(bridgeAddr).delayedTransfers(transferId).timestamp == 0, "transfer delayed");
        return keccak256(abi.encodePacked(MsgDataTypes.MsgType.MessageWithTransfer, bridgeAddr, transferId));
    }

    function computeMessageOnlyId(MsgDataTypes.Route memory _route, bytes calldata _message)
        private
        view
        returns (bytes32)
    {
        bytes memory sender = _route.senderBytes;
        if (sender.length == 0) {
            sender = abi.encodePacked(_route.sender);
        }
        return
            keccak256(
                abi.encodePacked(
                    MsgDataTypes.MsgType.MessageOnly,
                    sender,
                    _route.receiver,
                    _route.srcChainId,
                    _route.srcTxHash,
                    uint64(block.chainid),
                    _message
                )
            );
    }

    function executeMessage(MsgDataTypes.Route memory _route, bytes calldata _message)
        private
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        uint256 gasLeftBeforeExecution = gasleft();
        bool ok;
        bytes memory res;
        if (_route.senderBytes.length == 0) {
            (ok, res) = address(_route.receiver).call{value: msg.value}(
                abi.encodeWithSelector(
                    bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)"))),
                    _route.sender,
                    _route.srcChainId,
                    _message,
                    msg.sender
                )
            );
        } else {
            (ok, res) = address(_route.receiver).call{value: msg.value}(
                abi.encodeWithSelector(
                    bytes4(keccak256(bytes("executeMessage(bytes,uint64,bytes,address)"))),
                    _route.senderBytes,
                    _route.srcChainId,
                    _message,
                    msg.sender
                )
            );
        }
        if (ok) {
            return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        }
        handleExecutionRevert(gasLeftBeforeExecution, res);
        return IMessageReceiverApp.ExecutionStatus.Fail;
    }

    function handleExecutionRevert(uint256 _gasLeftBeforeExecution, bytes memory _returnData) private {
        uint256 gasLeftAfterExecution = gasleft();
        uint256 maxTargetGasLimit = block.gaslimit - preExecuteMessageGasUsage;
        if (_gasLeftBeforeExecution < maxTargetGasLimit && gasLeftAfterExecution <= _gasLeftBeforeExecution / 64) {
            // if this happens, the executor must have not provided sufficient gas limit,
            // then the tx should revert instead of recording a non-retryable failure status
            // https://github.com/wolflo/evm-opcodes/blob/main/gas.md#aa-f-gas-to-send-with-call-operations
            assembly {
                invalid()
            }
        }
        string memory revertMsg = Utils.getRevertMsg(_returnData);
        // revert the execution if the revert message has the ABORT prefix
        checkAbortPrefix(revertMsg);
        // otherwiase, emit revert message, return and mark the execution as failed (non-retryable)
        emit CallReverted(revertMsg);
    }

    function checkAbortPrefix(string memory _revertMsg) private pure {
        bytes memory prefixBytes = bytes(MsgDataTypes.ABORT_PREFIX);
        bytes memory msgBytes = bytes(_revertMsg);
        if (msgBytes.length >= prefixBytes.length) {
            for (uint256 i = 0; i < prefixBytes.length; i++) {
                if (msgBytes[i] != prefixBytes[i]) {
                    return; // prefix not match, return
                }
            }
            revert(_revertMsg); // prefix match, revert
        }
    }

    function getRouteInfo(MsgDataTypes.RouteInfo calldata _route) private pure returns (MsgDataTypes.Route memory) {
        return MsgDataTypes.Route(_route.sender, "", _route.receiver, _route.srcChainId, _route.srcTxHash);
    }

    function getRouteInfo(MsgDataTypes.RouteInfo2 calldata _route) private pure returns (MsgDataTypes.Route memory) {
        return MsgDataTypes.Route(address(0), _route.sender, _route.receiver, _route.srcChainId, _route.srcTxHash);
    }

    // ================= helper functions =====================

    /**
     * @notice combine bridge transfer and msg execution calls into a single tx
     * @dev caller needs to get the required input params from SGN
     * @param _tp params to call bridge transfer
     * @param _mp params to execute message
     */
    function transferAndExecuteMsg(
        MsgDataTypes.BridgeTransferParams calldata _tp,
        MsgDataTypes.MsgWithTransferExecutionParams calldata _mp
    ) external {
        _bridgeTransfer(_mp.transfer.t, _tp);
        executeMessageWithTransfer(_mp.message, _mp.transfer, _mp.sigs, _mp.signers, _mp.powers);
    }

    /**
     * @notice combine bridge refund and msg execution calls into a single tx
     * @dev caller needs to get the required input params from SGN
     * @param _tp params to call bridge transfer for refund
     * @param _mp params to execute message for refund
     */
    function refundAndExecuteMsg(
        MsgDataTypes.BridgeTransferParams calldata _tp,
        MsgDataTypes.MsgWithTransferExecutionParams calldata _mp
    ) external {
        _bridgeTransfer(_mp.transfer.t, _tp);
        executeMessageWithTransferRefund(_mp.message, _mp.transfer, _mp.sigs, _mp.signers, _mp.powers);
    }

    function _bridgeTransfer(MsgDataTypes.TransferType t, MsgDataTypes.BridgeTransferParams calldata _params) private {
        if (t == MsgDataTypes.TransferType.LqRelay) {
            IBridge(liquidityBridge).relay(_params.request, _params.sigs, _params.signers, _params.powers);
        } else if (t == MsgDataTypes.TransferType.LqWithdraw) {
            IBridge(liquidityBridge).withdraw(_params.request, _params.sigs, _params.signers, _params.powers);
        } else if (t == MsgDataTypes.TransferType.PegMint) {
            IPeggedTokenBridge(pegBridge).mint(_params.request, _params.sigs, _params.signers, _params.powers);
        } else if (t == MsgDataTypes.TransferType.PegV2Mint) {
            IPeggedTokenBridgeV2(pegBridgeV2).mint(_params.request, _params.sigs, _params.signers, _params.powers);
        } else if (t == MsgDataTypes.TransferType.PegWithdraw) {
            IOriginalTokenVault(pegVault).withdraw(_params.request, _params.sigs, _params.signers, _params.powers);
        } else if (t == MsgDataTypes.TransferType.PegV2Withdraw) {
            IOriginalTokenVaultV2(pegVaultV2).withdraw(_params.request, _params.sigs, _params.signers, _params.powers);
        }
    }

    // ================= contract config =================

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

    function setPreExecuteMessageGasUsage(uint256 _usage) public onlyOwner {
        preExecuteMessageGasUsage = _usage;
    }
}
