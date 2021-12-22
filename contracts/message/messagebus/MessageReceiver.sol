// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../framework/IBridge.sol";
import "../framework/MsgReceiverApp.sol";

contract MessageReceiver is Ownable {
    enum TransferType {
        Null,
        LqSend, // send through liquidity bridge
        LqWithdraw, // withdraw from liquidity bridge
        PegMint, // mint through pegged token bridge
        PegWithdraw // withdraw from original token vault
    }

    struct TransferInfo {
        TransferType t;
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint64 seqnum;
        uint64 srcChainId;
        bytes32 refId;
    }

    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback
    }
    mapping(bytes32 => TxStatus) private executedTransfers; // messages with associated transfer
    mapping(bytes32 => TxStatus) private executedMessages; // messages without associated transfer

    address public liquidityBridge; // liquidity bridge address
    address public pegBridge; // peg bridge address
    address public pegVault; // peg original vault address

    // ============== functions called by executor ==============

    function executeMessageWithTransfer(
        bytes calldata _message,
        TransferInfo memory _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 transferId = verifyTransfer(_transfer);
        require(executedTransfers[transferId] == TxStatus.Null, "transfer already executed");

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        IBridge(liquidityBridge).verifySigs(abi.encodePacked(domain, transferId, _message), _sigs, _signers, _powers);
        bool ok = executeMessageWithTransfer(_transfer, _message);
        if (ok) {
            executedTransfers[transferId] = TxStatus.Success;
        } else {
            ok = executeMessageWithTransferFallback(_transfer, _message);
            if (ok) {
                executedTransfers[transferId] = TxStatus.Fallback;
            } else {
                executedTransfers[transferId] = TxStatus.Fail;
            }
        }
    }

    function executeMessage(
        address _sender,
        address _receiver,
        uint64 _srcChainId,
        bytes calldata _message,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 messageId = keccak256(abi.encodePacked(_sender, _receiver, _srcChainId, _message));
        require(executedMessages[messageId] == TxStatus.Null, "message already executed");

        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Message"));
        IBridge(liquidityBridge).verifySigs(abi.encodePacked(domain, messageId), _sigs, _signers, _powers);
        (bool ok, ) = address(_receiver).call(
            abi.encodeWithSelector(MsgReceiverApp.executeMessage.selector, _sender, _srcChainId, _message)
        );
        if (ok) {
            executedTransfers[messageId] = TxStatus.Success;
        } else {
            executedTransfers[messageId] = TxStatus.Fail;
        }
    }

    // ================= utils =================

    // to avoid stack too deep
    function executeMessageWithTransfer(TransferInfo memory _transfer, bytes memory _message) private returns (bool) {
        (bool ok, ) = address(_transfer.receiver).call(
            abi.encodeWithSelector(
                MsgReceiverApp.executeMessageWithTransfer.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message
            )
        );
        return ok;
    }

    function executeMessageWithTransferFallback(TransferInfo memory _transfer, bytes memory _message)
        private
        returns (bool)
    {
        (bool ok, ) = address(_transfer.receiver).call(
            abi.encodeWithSelector(
                MsgReceiverApp.executeMessageWithTransferFallback.selector,
                _transfer.sender,
                _transfer.token,
                _transfer.amount,
                _transfer.srcChainId,
                _message
            )
        );
        return ok;
    }

    function verifyTransfer(TransferInfo memory _transfer) private view returns (bytes32) {
        bytes32 transferId;
        address bridgeAddr;
        if (_transfer.t == TransferType.LqSend) {
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
        } else if (_transfer.t == TransferType.LqWithdraw) {
            transferId = keccak256(
                abi.encodePacked(
                    uint64(block.chainid),
                    _transfer.seqnum,
                    _transfer.receiver,
                    _transfer.token,
                    _transfer.amount
                )
            );
            bridgeAddr = liquidityBridge;
            require(IBridge(bridgeAddr).withdraws(transferId) == true, "bridge withdraw not exist");
        } else if (_transfer.t == TransferType.PegMint || _transfer.t == TransferType.PegWithdraw) {
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
            if (_transfer.t == TransferType.PegMint) {
                bridgeAddr = pegBridge;
            } else {
                bridgeAddr = pegVault;
            }
            require(IBridge(bridgeAddr).records(transferId) == true, "peg record not exist");
        }
        transferId = keccak256(abi.encodePacked(bridgeAddr, transferId));
        return transferId;
    }

    // ================= contract addr config =================

    function setLiquidityBridge(address _addr) public onlyOwner {
        liquidityBridge = _addr;
    }

    function setPegBridge(address _addr) public onlyOwner {
        pegBridge = _addr;
    }

    function setPegVault(address _addr) public onlyOwner {
        pegVault = _addr;
    }
}
