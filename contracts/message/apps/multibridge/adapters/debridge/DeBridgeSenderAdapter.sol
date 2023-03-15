// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../../interfaces/IBridgeSenderAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDeBridgeGate.sol";
import "./interfaces/IDeBridgeReceiverAdapter.sol";

contract DeBridgeSenderAdapter is IBridgeSenderAdapter, Ownable {
    /* ========== STATE VARIABLES ========== */

    string public constant name = "deBridge";
    address public multiBridgeSender;
    IDeBridgeGate public immutable deBridgeGate;
    uint32 public nonce;

    // dstChainId => receiverAdapter address
    mapping(uint256 => address) public receiverAdapters;

    /* ========== EVENTS ========== */

    event ReceiverAdapterUpdated(uint256 dstChainId, address receiverAdapter);
    event MultiBridgeSenderUpdated(address oldMultiBridgeSender, address newMultiBridgeSender);

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

    function getMessageFee(
        uint256,
        address,
        bytes calldata
    ) external view returns (uint256) {
        return deBridgeGate.globalFixedNativeFee();
    }

    function dispatchMessage(
        uint256 _toChainId,
        address _to,
        bytes calldata _data
    ) external payable override onlyMultiBridgeSender returns (bytes32) {
        require(receiverAdapters[_toChainId] != address(0), "no receiver adapter");
        address receiver = receiverAdapters[_toChainId];
        bytes32 msgId = bytes32(uint256(nonce));
        bytes memory executeMethodData = abi.encodeWithSelector(
            IDeBridgeReceiverAdapter.executeMessage.selector,
            msg.sender,
            _to,
            _data,
            msgId
        );

        deBridgeGate.sendMessage{value: msg.value}(
            _toChainId, //_dstChainId,
            abi.encodePacked(receiver), //_targetContractAddress
            executeMethodData //_targetContractCalldata,
        );

        emit MessageDispatched(msgId, msg.sender, _toChainId, _to, _data);
        nonce++;
        return msgId;
    }

    /* ========== ADMIN METHODS ========== */

    function updateReceiverAdapter(uint256[] calldata _dstChainIds, address[] calldata _receiverAdapters)
        external
        override
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i; i < _dstChainIds.length; ++i) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
            emit ReceiverAdapterUpdated(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    function setMultiBridgeSender(address _multiBridgeSender) external override onlyOwner {
        address oldMultiBridgeSender = multiBridgeSender;
        multiBridgeSender = _multiBridgeSender;
        emit MultiBridgeSenderUpdated(oldMultiBridgeSender, multiBridgeSender);
    }
}
