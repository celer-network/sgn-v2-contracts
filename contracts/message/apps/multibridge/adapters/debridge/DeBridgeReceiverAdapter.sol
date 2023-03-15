// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../interfaces/IBridgeReceiverAdapter.sol";
import "./interfaces/IDeBridgeReceiverAdapter.sol";
import "./interfaces/IDeBridgeGate.sol";
import "./interfaces/ICallProxy.sol";

contract DeBridgeReceiverAdapter is Ownable, Pausable, IDeBridgeReceiverAdapter, IBridgeReceiverAdapter {
    /* ========== STATE VARIABLES ========== */

    mapping(uint256 => address) public senderAdapters;
    IDeBridgeGate public immutable deBridgeGate;
    mapping(bytes32 => bool) public executedMessages;

    /* ========== ERRORS ========== */

    error CallProxyBadRole();
    error NativeSenderBadRole(address nativeSender, uint256 chainIdFrom);

    /* ========== EVENTS ========== */

    event SenderAdapterUpdated(uint256 srcChainId, address senderAdapter);

    /* ========== CONSTRUCTOR  ========== */

    constructor(IDeBridgeGate _deBridgeGate) {
        deBridgeGate = _deBridgeGate;
    }

    /* ========== PUBLIC METHODS ========== */

    // Called by DeBridge CallProxy on destination chain to receive cross-chain messages.
    function executeMessage(
        address _multiBridgeSender,
        address _multiBridgeReceiver,
        bytes calldata _data,
        bytes32 _msgId
    ) external whenNotPaused {
        ICallProxy callProxy = ICallProxy(deBridgeGate.callProxy());
        if (address(callProxy) != msg.sender) revert CallProxyBadRole();

        address nativeSender = toAddress(callProxy.submissionNativeSender(), 0);
        uint256 submissionChainIdFrom = callProxy.submissionChainIdFrom();

        if (senderAdapters[submissionChainIdFrom] != nativeSender) {
            revert NativeSenderBadRole(nativeSender, submissionChainIdFrom);
        }

        if (executedMessages[_msgId]) {
            revert MessageIdAlreadyExecuted(_msgId);
        } else {
            executedMessages[_msgId] = true;
        }
        (bool ok, bytes memory lowLevelData) = _multiBridgeReceiver.call(
            abi.encodePacked(_data, _msgId, submissionChainIdFrom, _multiBridgeSender)
        );
        if (!ok) {
            revert MessageFailure(_msgId, lowLevelData);
        } else {
            emit MessageIdExecuted(submissionChainIdFrom, _msgId);
        }
    }

    /* ========== ADMIN METHODS ========== */

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateSenderAdapter(uint256[] calldata _srcChainIds, address[] calldata _senderAdapters)
        external
        override
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i; i < _srcChainIds.length; ++i) {
            senderAdapters[uint256(_srcChainIds[i])] = _senderAdapters[i];
            emit SenderAdapterUpdated(_srcChainIds[i], _senderAdapters[i]);
        }
    }

    /* ========== INTERNAL METHODS ========== */

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }
}
