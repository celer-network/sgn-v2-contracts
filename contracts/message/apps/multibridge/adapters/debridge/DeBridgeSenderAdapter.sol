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

    event SentMessage(bytes32 submissionId, uint256 toChainId, address to, bytes data);
    event ReceiverAdapterUpdated(uint256 dstChainId, address receiverAdapter);
    event MultiBridgeSenderSet(address multiBridgeSender);

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
        bytes memory executeMethodData = abi.encodeWithSelector(
            IDeBridgeReceiverAdapter.executeMessage.selector,
            msg.sender,
            _to,
            _data,
            bytes32(uint256(nonce++))
        );

        bytes32 submissionId = deBridgeGate.sendMessage{value: msg.value}(
            _toChainId, //_dstChainId,
            abi.encodePacked(receiver), //_targetContractAddress
            executeMethodData //_targetContractCalldata,
        );

        emit SentMessage(submissionId, _toChainId, _to, _data);
        return bytes32(uint256(nonce++));
    }

    /* ========== ADMIN METHODS ========== */

    function updateReceiverAdapter(uint256[] calldata _dstChainIds, address[] calldata _receiverAdapters)
        external
        override
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _dstChainIds.length; i++) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
            emit ReceiverAdapterUpdated(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    function setMultiBridgeSender(address _multiBridgeSender) external override onlyOwner {
        multiBridgeSender = _multiBridgeSender;
        emit MultiBridgeSenderSet(_multiBridgeSender);
    }
}
