// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../../safeguard/MessageAppPauser.sol";
import "./IUniswapMultiMsgReceiver.sol";
import "../../../libraries/Utils.sol";

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

contract CelerMsgReceiver is MessageAppPauser, IMessageReceiverApp {
    address public immutable msgSender;
    address public immutable msgBus;

    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    constructor(address _msgBus, address _msgSender) {
        msgBus = _msgBus;
        msgSender = _msgSender;
    }

    // Called by MessageBus on destination chain to receive cross-chain messages.
    // The message is abi.encode of (dst_contract_address, dst_contract_calldata).
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus whenNotMsgPaused returns (ExecutionStatus) {
        (IUniswapMultiMsgReceiver.Message memory message) = abi.decode(_message, (IUniswapMultiMsgReceiver.Message));
        require(_srcContract == msgSender, "not allowed message sender");
        require(_srcChainId == 1, "invalid src chain id");
        try IUniswapMultiMsgReceiver(message.multiMsgReceiver).relayMessage(message) {
        } catch (bytes memory lowLevelData) {
            revert(Utils.getRevertMsg(lowLevelData));
        }
        return ExecutionStatus.Success;
    }
}
