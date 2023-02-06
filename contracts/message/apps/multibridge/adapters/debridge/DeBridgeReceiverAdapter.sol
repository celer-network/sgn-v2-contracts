// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../interfaces/IMultiBridgeReceiver.sol";
import "./interfaces/IDeBridgeReceiverAdapter.sol";
import "./interfaces/IDeBridgeGate.sol";
import "./interfaces/ICallProxy.sol";
import "../../MessageStruct.sol";

contract DeBridgeReceiverAdapter is Ownable, Pausable, IDeBridgeReceiverAdapter {
    /* ========== STATE VARIABLES ========== */

    mapping(uint256 => address) public senderAdapters;
    IDeBridgeGate public immutable deBridgeGate;
    address public multiBridgeReceiver;

    /* ========== ERRORS ========== */

    error CallProxyBadRole();
    error NativeSenderBadRole(address nativeSender, uint256 chainIdFrom);

    /* ========== EVENTS ========== */

    event SentMessage(bytes32 submissionId, MessageStruct.Message _message);
    event UpdatedSenderAdapter(uint256 srcChainId, address senderAdapter);

    /* ========== MODIFIERS ========== */

    modifier onlySenderAdapter() {
        ICallProxy callProxy = ICallProxy(deBridgeGate.callProxy());
        if (address(callProxy) != msg.sender) revert CallProxyBadRole();

        address nativeSender = toAddress(callProxy.submissionNativeSender(), 0);
        uint256 submissionChainIdFrom = callProxy.submissionChainIdFrom();

        if (senderAdapters[submissionChainIdFrom] != nativeSender) {
            revert NativeSenderBadRole(nativeSender, submissionChainIdFrom);
        }
        _;
    }

    /* ========== CONSTRUCTOR  ========== */

    constructor(IDeBridgeGate _deBridgeGate) {
        deBridgeGate = _deBridgeGate;
    }

    /* ========== PUBLIC METHODS ========== */

    // Called by DeBridge CallProxy on destination chain to receive cross-chain messages.
    function executeMessage(MessageStruct.Message memory _message) external onlySenderAdapter whenNotPaused {
        IMultiBridgeReceiver(multiBridgeReceiver).receiveMessage(_message);
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
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _srcChainIds.length; i++) {
            senderAdapters[_srcChainIds[i]] = _senderAdapters[i];
        }
    }

    function setMultiBridgeReceiver(address _multiBridgeReceiver) external onlyOwner {
        multiBridgeReceiver = _multiBridgeReceiver;
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
