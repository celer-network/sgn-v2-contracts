// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../../../../safeguard/MessageAppPauser.sol";
import "../../../../../libraries/Utils.sol";
import "../../interfaces/IMultiBridgeReceiver.sol";
import "../../interfaces/IBridgeReceiverAdapter.sol";
import "../../MessageStruct.sol";

interface IMessageReceiverApp {
    enum ExecutionStatus {
        Fail, // execution failed, finalized
        Success, // execution succeeded, finalized
        Retry // execution rejected, can retry later
    }

    /**
     * @notice Called by MessageBus to execute a message
     * @param _sender The address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);
}

contract CelerReceiverAdapter is IBridgeReceiverAdapter, MessageAppPauser, IMessageReceiverApp {
    string constant ABORT_PREFIX = "MSG::ABORT:";
    mapping(uint256 => address) public senderAdapters;
    address public immutable msgBus;
    mapping(bytes32 => bool) public executedMessages;

    event SenderAdapterUpdated(uint256 srcChainId, address senderAdapter);

    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    constructor(address _msgBus) {
        msgBus = _msgBus;
    }

    // Called by MessageBus on destination chain to receive cross-chain messages.
    // The message is abi.encode of (MessageStruct.Message).
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus whenNotMsgPaused returns (ExecutionStatus) {
        (bytes32 msgId, address multiBridgeSender, address multiBridgeReceiver, bytes memory data) = abi.decode(
            _message,
            (bytes32, address, address, bytes)
        );
        require(_srcContract == senderAdapters[uint256(_srcChainId)], "not allowed message sender");
        if (executedMessages[msgId]) {
            revert MessageIdAlreadyExecuted(msgId);
        } else {
            executedMessages[msgId] = true;
        }
        (bool ok, bytes memory lowLevelData) = multiBridgeReceiver.call(
            abi.encodePacked(data, msgId, uint256(_srcChainId), multiBridgeSender)
        );
        if (!ok) {
            string memory reason = Utils.getRevertMsg(lowLevelData);
            revert(
                string.concat(
                    ABORT_PREFIX,
                    string(abi.encodeWithSelector(MessageFailure.selector, msgId, bytes(reason)))
                )
            );
        } else {
            emit MessageIdExecuted(uint256(_srcChainId), msgId);
            return ExecutionStatus.Success;
        }
    }

    function updateSenderAdapter(uint256[] calldata _srcChainIds, address[] calldata _senderAdapters)
        external
        override
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _srcChainIds.length; i++) {
            senderAdapters[_srcChainIds[i]] = _senderAdapters[i];
            emit SenderAdapterUpdated(_srcChainIds[i], _senderAdapters[i]);
        }
    }
}
