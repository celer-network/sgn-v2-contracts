// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./interfaces/IBridgeSenderAdapter.sol";
import "./interfaces/IMultiBridgeReceiver.sol";
import "./MessageStruct.sol";

contract MultiBridgeSender {
    // List of bridge sender adapters
    address[] public senderAdapters;
    // The dApp contract that can use this multi-bridge sender for cross-chain remoteCall.
    // This means the current MultiBridgeSender is only intended to be used by a single dApp.
    address public immutable caller;
    uint32 public nonce;

    event MultiBridgeMsgSent(uint32 nonce, uint64 dstChainId, address target, bytes callData, address[] senderAdapters);
    event SenderAdapterUpdated(address senderAdapter, bool add); // add being false indicates removal of the adapter
    event ErrorSendMessage(address senderAdapters, MessageStruct.Message message);

    modifier onlyCaller() {
        require(msg.sender == caller, "not caller");
        _;
    }

    constructor(address _caller) {
        caller = _caller;
    }

    /**
     * @notice Call a remote function on a destination chain by sending multiple copies of a cross-chain message
     * via all available bridges.
     *
     * A fee in native token may be required by each message bridge to send messages. Any native token fee remained
     * will be refunded back to msg.sender, which requires caller being able to receive native token.
     * Caller can use estimateTotalMessageFee() to get total message fees before calling this function.
     *
     * @param _dstChainId is the destination chainId.
     * @param _multiBridgeReceiver is the MultiBridgeReceiver address on destination chain.
     * @param _target is the contract address on the destination chain.
     * @param _callData is the data to be sent to _target by low-level call(eg. address(_target).call(_callData)).
     */
    function remoteCall(
        uint64 _dstChainId,
        address _multiBridgeReceiver,
        address _target,
        bytes calldata _callData
    ) external payable onlyCaller {
        MessageStruct.Message memory message = MessageStruct.Message(
            uint64(block.chainid),
            _dstChainId,
            nonce,
            _target,
            _callData,
            ""
        );
        bytes memory data;
        uint256 totalFee;
        // send copies of the message through multiple bridges
        for (uint256 i; i < senderAdapters.length; ++i) {
            message.bridgeName = IBridgeSenderAdapter(senderAdapters[i]).name();
            data = abi.encodeWithSelector(IMultiBridgeReceiver.receiveMessage.selector, message);
            uint256 fee = IBridgeSenderAdapter(senderAdapters[i]).getMessageFee(
                uint256(_dstChainId),
                _multiBridgeReceiver,
                data
            );
            // if one bridge is paused it shouldn't halt the process
            try
                IBridgeSenderAdapter(senderAdapters[i]).dispatchMessage{value: fee}(
                    uint256(_dstChainId),
                    _multiBridgeReceiver,
                    data
                )
            {
                totalFee += fee;
            } catch {
                emit ErrorSendMessage(senderAdapters[i], message);
            }
        }
        emit MultiBridgeMsgSent(nonce, _dstChainId, _target, _callData, senderAdapters);
        nonce++;
        // refund remaining native token to msg.sender
        if (totalFee < msg.value) {
            _safeTransferETH(msg.sender, msg.value - totalFee);
        }
    }

    /**
     * @notice Add bridge sender adapters
     */
    function addSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i; i < _senderAdapters.length; ++i) {
            _addSenderAdapter(_senderAdapters[i]);
        }
    }

    /**
     * @notice Remove bridge sender adapters
     */
    function removeSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i; i < _senderAdapters.length; ++i) {
            _removeSenderAdapter(_senderAdapters[i]);
        }
    }

    /**
     * @notice A helper function for estimating total required message fee by all available message bridges.
     */
    function estimateTotalMessageFee(
        uint64 _dstChainId,
        address _multiBridgeReceiver,
        address _target,
        bytes calldata _callData
    ) public view returns (uint256) {
        MessageStruct.Message memory message = MessageStruct.Message(
            uint64(block.chainid),
            _dstChainId,
            nonce,
            _target,
            _callData,
            ""
        );
        bytes memory data;
        uint256 totalFee;
        for (uint256 i; i < senderAdapters.length; ++i) {
            message.bridgeName = IBridgeSenderAdapter(senderAdapters[i]).name();
            data = abi.encodeWithSelector(IMultiBridgeReceiver.receiveMessage.selector, message);
            uint256 fee = IBridgeSenderAdapter(senderAdapters[i]).getMessageFee(
                uint256(_dstChainId),
                _multiBridgeReceiver,
                data
            );
            totalFee += fee;
        }
        return totalFee;
    }

    function _addSenderAdapter(address _senderAdapter) private {
        for (uint256 i; i < senderAdapters.length; ++i) {
            if (senderAdapters[i] == _senderAdapter) {
                return;
            }
        }
        senderAdapters.push(_senderAdapter);
        emit SenderAdapterUpdated(_senderAdapter, true);
    }

    function _removeSenderAdapter(address _senderAdapter) private {
        uint256 lastIndex = senderAdapters.length - 1;
        for (uint256 i; i < senderAdapters.length; ++i) {
            if (senderAdapters[i] == _senderAdapter) {
                if (i < lastIndex) {
                    senderAdapters[i] = senderAdapters[lastIndex];
                }
                senderAdapters.pop();
                emit SenderAdapterUpdated(_senderAdapter, false);
                return;
            }
        }
    }

    /*
     * @dev transfer ETH to an address, revert if it fails.
     * @param to recipient of the transfer
     * @param value the amount to send
     */
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'safeTransferETH: ETH transfer failed');
    }
}
