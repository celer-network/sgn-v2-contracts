// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./IBridge.sol";
import "./Addrs.sol";

abstract contract MessageReceiver is Addrs {
    mapping(bytes32 => bool) private handledTransfers;

    enum TransferType {
        Invalid,
        LqSend, // send through liquidity bridge
        LqWithdraw, // withdraw from liquidity bridge
        PegMint, // mint through pegged token bridge
        PegWithdraw // withdraw from original token vault
    }

    struct TransferInfo {
        TransferType t;
        address sender;
        address token;
        uint256 amount;
        uint64 seqnum;
        uint64 srcChainId;
        bytes32 refId;
    }

    // ========= virtual functions to be implemented by apps =========

    function handleMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    function handleMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    // ============== functions called by executor ==============

    function executeMessageWithTransfer(
        bytes calldata _message,
        TransferInfo memory _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "MessageWithTransfer"));
        bytes32 transferId = verifyTransferId(_transfer);
        IBridge(liquidityBridge).verifySigs(abi.encodePacked(domain, transferId, _message), _sigs, _signers, _powers);
        handleMessageWithTransfer(_transfer, _message);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Message"));
        IBridge(liquidityBridge).verifySigs(
            abi.encodePacked(domain, _sender, _srcChainId, _message),
            _sigs,
            _signers,
            _powers
        );
        handleMessage(_sender, _srcChainId, _message);
    }

    // ================= utils =================

    // to avoid stack too deep
    function handleMessageWithTransfer(TransferInfo memory _transfer, bytes memory _message) private {
        handleMessageWithTransfer(_transfer.sender, _transfer.token, _transfer.amount, _transfer.srcChainId, _message);
    }

    function verifyTransferId(TransferInfo memory _transfer) private returns (bytes32) {
        bytes32 transferId;
        address bridgeAddr;
        if (_transfer.t == TransferType.LqSend) {
            transferId = keccak256(
                abi.encodePacked(
                    _transfer.sender,
                    address(this),
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
                    address(this),
                    _transfer.token,
                    _transfer.amount
                )
            );
            bridgeAddr = liquidityBridge;
            require(IBridge(bridgeAddr).withdraws(transferId) == true, "bridge withdraw not exist");
        } else if (_transfer.t == TransferType.PegMint || _transfer.t == TransferType.PegWithdraw) {
            transferId = keccak256(
                abi.encodePacked(
                    address(this),
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
        bytes32 id = keccak256(abi.encodePacked(bridgeAddr, transferId));
        require(handledTransfers[id] == false, "transfer already handled");
        handledTransfers[id] = true;
        return transferId;
    }
}
