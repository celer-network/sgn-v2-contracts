// SPDX-License-Identifier: Apache 2

pragma solidity >=0.8.9;

import "../../interfaces/IBridgeSenderAdapter.sol";
import "../../MessageStruct.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWormhole {
    function publishMessage(
        uint32 nonce,
        bytes memory payload,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence);

    function messageFee() external view returns (uint256);
}

interface IRelayProvider {}

interface ICoreRelayer {
    /**
     * @dev This is the basic function for requesting delivery
     */
    function requestDelivery(
        DeliveryRequest memory request,
        uint32 nonce,
        IRelayProvider provider
    ) external payable returns (uint64 sequence);

    function getDefaultRelayProvider() external returns (IRelayProvider);

    function getDefaultRelayParams() external pure returns (bytes memory relayParams);

    function quoteGasDeliveryFee(
        uint16 targetChain,
        uint32 gasLimit,
        IRelayProvider relayProvider
    ) external pure returns (uint256 deliveryQuote);

    function quoteApplicationBudgetFee(
        uint16 targetChain,
        uint256 targetAmount,
        IRelayProvider provider
    ) external pure returns (uint256 nativeQuote);

    struct DeliveryRequest {
        uint16 targetChain;
        bytes32 targetAddress;
        bytes32 refundAddress;
        uint256 computeBudget;
        uint256 applicationBudget;
        bytes relayParameters; //Optional
    }
}

contract WormholeSenderAdapter is IBridgeSenderAdapter, Ownable {
    string public name = "wormhole";
    address public multiBridgeSender;
    mapping(uint64 => uint16) idMap;
    // dstChainId => receiverAdapter address
    mapping(uint16 => address) public receiverAdapters;

    uint8 consistencyLevel = 1;

    event MessageSent(bytes payload, address indexed messageReceiver);
    event ReceiverAdapterUpdated(uint64 dstChainId, address receiverAdapter);
    event MultiBridgeSenderSet(address multiBridgeSender);

    IWormhole private immutable wormhole;
    ICoreRelayer private immutable relayer;
    IRelayProvider private relayProvider;

    constructor(address _bridgeAddress, address _relayer) {
        wormhole = IWormhole(_bridgeAddress);
        relayer = ICoreRelayer(_relayer);
        relayProvider = relayer.getDefaultRelayProvider();
    }

    modifier onlyMultiBridgeSender() {
        require(msg.sender == multiBridgeSender, "not multi-bridge msg sender");
        _;
    }

    function getMessageFee(MessageStruct.Message memory _message) external view override returns (uint256) {
        uint256 fee = wormhole.messageFee();
        uint256 deliveryCost = relayer.quoteGasDeliveryFee(idMap[_message.dstChainId], 500000, relayProvider);
        uint256 applicationBudget = relayer.quoteApplicationBudgetFee(idMap[_message.dstChainId], 100, relayProvider);
        return fee + deliveryCost + applicationBudget;
    }

    function sendMessage(MessageStruct.Message memory _message) external payable override onlyMultiBridgeSender {
        _message.bridgeName = name;
        address receiverAdapter = receiverAdapters[idMap[_message.dstChainId]];
        require(receiverAdapter != address(0), "no receiver adapter");
        bytes memory payload = abi.encode(_message, receiverAdapter);
        uint256 msgFee = wormhole.messageFee();
        wormhole.publishMessage{value: msgFee}(_message.nonce, payload, consistencyLevel);

        uint256 relayFee = msg.value - msgFee;
        ICoreRelayer.DeliveryRequest memory request = ICoreRelayer.DeliveryRequest(
            idMap[_message.dstChainId], //targetChain
            bytes32(uint256(uint160(receiverAdapter))), //targetAddress
            bytes32(uint256(uint160(address(this)))), //refundAddress
            relayFee, //computeBudget
            0, //applicationBudget
            relayer.getDefaultRelayParams() //relayerParams
        );
        relayer.requestDelivery{value: relayFee}(request, _message.nonce, relayProvider);

        emit MessageSent(payload, receiverAdapter);
    }

    function setChainIdMap(uint64[] calldata _origIds, uint16[] calldata _whIds) external onlyOwner {
        require(_origIds.length == _whIds.length, "mismatch length");
        for (uint256 i = 0; i < _origIds.length; i++) {
            idMap[_origIds[i]] = _whIds[i];
        }
    }

    function updateReceiverAdapter(uint64[] calldata _dstChainIds, address[] calldata _receiverAdapters)
        external
        override
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _dstChainIds.length; i++) {
            uint16 wormholeId = idMap[_dstChainIds[i]];
            require(wormholeId != 0, "unrecognized dstChainId");
            receiverAdapters[wormholeId] = _receiverAdapters[i];
            emit ReceiverAdapterUpdated(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    function setMultiBridgeSender(address _multiBridgeSender) external override onlyOwner {
        multiBridgeSender = _multiBridgeSender;
        emit MultiBridgeSenderSet(_multiBridgeSender);
    }
}
