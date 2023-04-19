// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../../framework/MessageApp.sol";
import "../../safeguard/MessageAppPauser.sol";
import "../../safeguard/DelayedMessage.sol";
import "../../../libraries/Utils.sol";

contract MessageReceiverAdapter is MessageApp, MessageAppPauser, DelayedMessage {
    event ExternalCall(address srcContract, uint64 srcChainId, address dstContract, bytes callData);
    event AllowedSenderUpdated(address dstContract, uint64 srcChainId, address srcContract, bool allowed);

    // dstContract => srcChainId => srcContract => allowed or not
    mapping(address => mapping(uint64 => mapping(address => bool))) public allowedSender;

    constructor(address _messageBus) MessageApp(_messageBus) {}

    // Called by MessageBus on destination chain to receive cross-chain messages.
    // The message is abi.encode of (dst_contract_address, dst_contract_calldata).
    // If a delayed period is configured, the message would be put in a delayed message queue,
    // otherwise, the external call to the dst contract will be executed immediately
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus whenNotMsgPaused returns (ExecutionStatus) {
        (address dstContract, bytes memory callData) = abi.decode(_message, (address, bytes));
        require(allowedSender[dstContract][_srcChainId][_srcContract], "not allowed sender");
        if (delayPeriod > 0) {
            _addDelayedMessage(_srcContract, _srcChainId, _message);
        } else {
            _externalCall(_srcContract, _srcChainId, dstContract, callData);
        }
        return ExecutionStatus.Success;
    }

    // execute external call to the dst contract after the message delay period is passed.
    function executeDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        uint32 _nonce
    ) external payable whenNotPaused {
        _executeDelayedMessage(_srcContract, _srcChainId, _message, _nonce);
        (address dstContract, bytes memory callData) = abi.decode(_message, (address, bytes));
        _externalCall(_srcContract, _srcChainId, dstContract, callData);
    }

    function _externalCall(
        address _srcContract,
        uint64 _srcChainId,
        address _dstContract,
        bytes memory _callData
    ) internal {
        (bool ok, bytes memory returnData) = _dstContract.call{value: msg.value}(_callData);
        if (!ok) {
            revert(Utils.getRevertMsg(returnData));
        }
        emit ExternalCall(_srcContract, _srcChainId, _dstContract, _callData);
    }

    function setAllowedSender(
        address _dstContract,
        uint64 _srcChainId,
        address[] calldata _srcContracts,
        bool[] calldata _alloweds
    ) external onlyOwner {
        require(_srcContracts.length == _alloweds.length, "length mismatch");
        for (uint256 i = 0; i < _srcContracts.length; i++) {
            allowedSender[_dstContract][_srcChainId][_srcContracts[i]] = _alloweds[i];
            emit AllowedSenderUpdated(_dstContract, _srcChainId, _srcContracts[i], _alloweds[i]);
        }
    }
}
