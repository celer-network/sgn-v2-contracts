// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../../framework/MessageApp.sol";
import "../../../safeguard/Pauser.sol";
import "../../../safeguard/DelayedMessage.sol";

// A HelloWorld example for basic cross-chain message passing
contract MessageReceiverAdapter is MessageApp, DelayedMessage, Pauser {
    event MessageReceived(address srcContract, uint64 srcChainId, address dstContract, bytes callData);
    event AllowedSenderUpdated(address dstContract, uint64 srcChainId, address srcContract, bool allowed);

    // dstContract => srcChainId => srcContract => allowed or not
    mapping(address => mapping(uint64 => mapping(address => bool))) public allowedSender;

    constructor(address _messageBus) MessageApp(_messageBus) {}

    // called by MessageBus on destination chain to receive cross-chain messages
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus whenNotPaused returns (ExecutionStatus) {
        (address dstContract, bytes memory callData) = abi.decode(_message, (address, bytes));
        require(allowedSender[dstContract][_srcChainId][_srcContract], "not allowed sender");
        bool delay = delayPeriod > 0 ? true : false;
        if (delay) {
            _addDelayedMessage(_srcContract, _srcChainId, dstContract, callData);
            return ExecutionStatus.Success;
        }
        emit MessageReceived(_srcContract, _srcChainId, dstContract, callData);
        return externalCall(dstContract, callData);
    }

    function executeDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        address _dstContract,
        bytes calldata _callData,
        uint32 _nonce
    ) external payable whenNotPaused {
        _executeDelayedMessage(_srcContract, _srcChainId, _dstContract, _callData, _nonce);
        externalCall(_dstContract, _callData);
        emit MessageReceived(_srcContract, _srcChainId, _dstContract, _callData);
    }

    // as long as external call is good, execution status would be considered always as Success.
    function externalCall(address _dstContract, bytes memory _callData) internal returns (ExecutionStatus) {
        (bool ok, bytes memory returnData) = _dstContract.call{value: msg.value}(_callData);
        if (!ok) {
            // Bubble up the revert from the returnData
            revert(getRevertMsg(returnData));
        }
        return ExecutionStatus.Success;
    }

    // https://ethereum.stackexchange.com/a/83577
    // https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/base/Multicall.sol
    function getRevertMsg(bytes memory _returnData) private pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    // =============== Admin operation ===============

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
