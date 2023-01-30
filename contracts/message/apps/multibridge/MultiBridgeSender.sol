// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./interfaces/IBridgeSenderAdapter.sol";
import "./MessageStruct.sol";

contract MultiBridgeSender {
    // current available senderAdapters of message bridges
    address[] public senderAdapters;
    // who has access to remoteCall function
    address public immutable caller;
    uint32 public nonce;

    event MultiBridgeMsgSent(uint32 nonce, uint64 dstChainId, address target, bytes callData, address[] senderAdapters);
    event SenderAdapterAdded(address senderAdapter);
    event SenderAdapterRemoved(address senderAdapter);

    modifier onlyCaller() {
        require(msg.sender == caller, "not caller");
        _;
    }

    constructor(address _caller) {
        caller = _caller;
    }

    /**
     * @notice Send cross-chain messages via all available message bridge to realize a remote call on destination chain.
     * Native token is required by each message bridge to send message. Any native token remained will be transfer back
     * to msg.sender, which requires caller should be able to receive native token.
     *
     * Better call estimateTotalMessageFee() for getting total message fee before calling
     * or preparing calldata for this function
     *
     * @param _dstChainId is the id of destination chain.
     * @param _target indicates where _callData is given to on dst chain.
     * @param _callData is the data to be sent to _target by low-level call(eg. address(_target).call(_callData)).
     */
    function remoteCall(
        uint64 _dstChainId,
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
        uint256 totalFee;
        for (uint256 i = 0; i < senderAdapters.length; i++) {
            uint256 fee = IBridgeSenderAdapter(senderAdapters[i]).getMessageFee(message);
            totalFee += fee;
            IBridgeSenderAdapter(senderAdapters[i]).sendMessage{value: fee}(message);
        }
        emit MultiBridgeMsgSent(nonce, _dstChainId, _target, _callData, senderAdapters);
        nonce++;
        // give back remaining native token to msg.sender
        if (totalFee < msg.value) {
            payable(msg.sender).transfer(msg.value - totalFee);
        }
    }

    /**
     * @notice Add the sender adapter of a new message bridge.
     * Supports adding multiple adapters at once.
     */
    function addSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i = 0; i < _senderAdapters.length; i++) {
            _addSenderAdapter(_senderAdapters[i]);
        }
    }

    /**
     * @notice Remove the sender adapter of an available message bridge.
     * Supports removing multiple adapters at once.
     */
    function removeSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i = 0; i < _senderAdapters.length; i++) {
            _removeSenderAdapter(_senderAdapters[i]);
        }
    }

    /**
     * @notice A helper function for estimating total required message fee by all available message bridges.
     */
    function estimateTotalMessageFee(
        uint64 _dstChainId,
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
        uint256 totalFee;
        for (uint256 i = 0; i < senderAdapters.length; i++) {
            uint256 fee = IBridgeSenderAdapter(senderAdapters[i]).getMessageFee(message);
            totalFee += fee;
        }
        return totalFee;
    }

    function _addSenderAdapter(address _senderAdapter) private {
        for (uint256 i = 0; i < senderAdapters.length; i++) {
            if (senderAdapters[i] == _senderAdapter) {
                return;
            }
        }
        senderAdapters.push(_senderAdapter);
        emit SenderAdapterAdded(_senderAdapter);
    }

    function _removeSenderAdapter(address _senderAdapter) private {
        uint256 lastIndex = senderAdapters.length - 1;
        for (uint256 i = 0; i < senderAdapters.length; i++) {
            if (senderAdapters[i] == _senderAdapter) {
                if (i < lastIndex) {
                    senderAdapters[i] = senderAdapters[lastIndex];
                }
                senderAdapters.pop();
                emit SenderAdapterRemoved(_senderAdapter);
                return;
            }
        }
    }
}
