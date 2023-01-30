// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../../../safeguard/MessageAppPauser.sol";
import "../IMultiBridgeReceiver.sol";
import "../MessageStruct.sol";
import "../../../../libraries/Utils.sol";

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

contract CelerReceiverAdapter is MessageAppPauser, IMessageReceiverApp {
    mapping(uint64 => address) public senderAdapters;
    address public immutable msgBus;
    address public immutable multiBridgeReceiver;

    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    constructor(address _multiBridgeReceiver, address _msgBus) {
        multiBridgeReceiver = _multiBridgeReceiver;
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
        MessageStruct.Message memory message = abi.decode(_message, (MessageStruct.Message));
        require(_srcContract == senderAdapters[_srcChainId], "not allowed message sender");
        IMultiBridgeReceiver(multiBridgeReceiver).receiveMessage(message);
        return ExecutionStatus.Success;
    }

    function updateSenderAdapter(uint64[] calldata _srcChainIds, address[] calldata _senderAdapters)
        external
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _srcChainIds.length; i++) {
            senderAdapters[_srcChainIds[i]] = _senderAdapters[i];
        }
    }
}
