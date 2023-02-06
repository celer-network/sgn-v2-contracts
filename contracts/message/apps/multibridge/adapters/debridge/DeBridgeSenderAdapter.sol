// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../../interfaces/IBridgeSenderAdapter.sol";
import "../../MessageStruct.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDeBridgeGate.sol";
import "./interfaces/IDeBridgeReceiverAdapter.sol";

contract DeBridgeSenderAdapter is IBridgeSenderAdapter, Ownable {
    /* ========== STATE VARIABLES ========== */

    string public constant name = "deBridge";
    address public multiBridgeSender;
    IDeBridgeGate public immutable deBridgeGate;

    // dstChainId => receiverAdapter address
    mapping(uint64 => address) public receiverAdapters;

    /* ========== EVENTS ========== */

    event SentMessage(bytes32 submissionId, MessageStruct.Message _message);
    event UpdatedReceiverAdapter(uint64 dstChainId, address receiverAdapter);

    /* ========== MODIFIERS ========== */

    modifier onlyMultiBridgeSender() {
        require(msg.sender == multiBridgeSender, "not multi-bridge msg sender");
        _;
    }

    /* ========== CONSTRUCTOR  ========== */

    constructor(IDeBridgeGate _deBridgeGate) {
        deBridgeGate = _deBridgeGate;
    }

    /* ========== PUBLIC METHODS ========== */

    function getMessageFee(MessageStruct.Message memory) external view returns (uint256) {
        return deBridgeGate.globalFixedNativeFee();
    }

    function sendMessage(MessageStruct.Message memory _message) external payable onlyMultiBridgeSender {
        _message.bridgeName = name;
        require(receiverAdapters[_message.dstChainId] != address(0), "no receiver adapter");
        address receiver = receiverAdapters[_message.dstChainId];
        bytes memory executeMethodData = abi.encodeWithSelector(
            IDeBridgeReceiverAdapter.executeMessage.selector,
            _message
        );

        bytes32 submissionId = deBridgeGate.sendMessage{value: msg.value}(
            _message.dstChainId, //_dstChainId,
            abi.encodePacked(receiver), //_targetContractAddress
            executeMethodData //_targetContractCalldata,
        );

        emit SentMessage(submissionId, _message);
    }

    /* ========== ADMIN METHODS ========== */

    function updateReceiverAdapter(uint64[] calldata _dstChainIds, address[] calldata _receiverAdapters)
        external
        override
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _dstChainIds.length; i++) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
            emit UpdatedReceiverAdapter(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    function setMultiBridgeSender(address _multiBridgeSender) external override onlyOwner {
        multiBridgeSender = _multiBridgeSender;
    }
}
