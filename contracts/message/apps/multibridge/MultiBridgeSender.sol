// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./ISenderAdapter.sol";
import "./MessageStruct.sol";

contract MultiBridgeSender {
    address[] public senderAdapters;
    address public caller;
    uint32 public nonce;

    event MultiBridgeMsgSent(uint32 nonce, uint64 dstChainId, address target, bytes callData, address[] senderAdapters);
    event SenderAdapterAdded(address senderAdapter);
    event SenderAdapterRemoved(address senderAdapter);

    modifier onlyCaller() {
        require(msg.sender == caller, "not caller");
        _;
    }

    constructor(address _caller, address[] memory _senderAdapters) {
        caller = _caller;
        for (uint256 i = 0; i < _senderAdapters.length; i++) {
            _addSenderAdapter(_senderAdapters[i]);
        }
    }

    /**
     * @param _target indicates where _callData is given to on dst chain.
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
            uint256 fee = ISenderAdapter(senderAdapters[i]).getMessageFee(message);
            totalFee += fee;
            ISenderAdapter(senderAdapters[i]).sendMessage{value: fee}(message);
        }
        emit MultiBridgeMsgSent(nonce, _dstChainId, _target, _callData, senderAdapters);
        nonce++;
        if (totalFee < msg.value) {
            payable(tx.origin).transfer(msg.value - totalFee);
        }
    }

    function addSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i = 0; i < _senderAdapters.length; i++) {
            _addSenderAdapter(_senderAdapters[i]);
        }
    }

    function removeSenderAdapters(address[] calldata _senderAdapters) external onlyCaller {
        for (uint256 i = 0; i < _senderAdapters.length; i++) {
            _removeSenderAdapter(_senderAdapters[i]);
        }
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
