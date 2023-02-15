// SPDX-License-Identifier: Apache 2

pragma solidity >=0.8.9;

import "../../interfaces/IMultiBridgeReceiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IBridgeReceiverAdapter.sol";

interface Structs {
    struct Provider {
        uint16 chainId;
        uint16 governanceChainId;
        bytes32 governanceContract;
    }

    struct GuardianSet {
        address[] keys;
        uint32 expirationTime;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 guardianIndex;
    }

    struct VM {
        uint8 version;
        uint32 timestamp;
        uint32 nonce;
        uint16 emitterChainId;
        bytes32 emitterAddress;
        uint64 sequence;
        uint8 consistencyLevel;
        bytes payload;
        uint32 guardianSetIndex;
        Signature[] signatures;
        bytes32 hash;
    }
}

interface IWormhole {
    function parseAndVerifyVM(bytes calldata encodedVM)
        external
        view
        returns (
            Structs.VM memory vm,
            bool valid,
            string memory reason
        );
}

interface IWormholeReceiver {
    function receiveWormholeMessages(bytes[] memory vaas, bytes[] memory additionalData) external payable;
}

contract WormholeReceiverAdapter is IBridgeReceiverAdapter, IWormholeReceiver, Ownable {
    mapping(uint256 => uint16) idMap;
    mapping(uint16 => uint256) reverseIdMap;
    mapping(uint16 => bytes32) public senderAdapters;
    IWormhole private immutable wormhole;
    address private immutable relayer;
    mapping(bytes32 => bool) public processedMessages;

    event SenderAdapterUpdated(uint256 srcChainId, address senderAdapter);

    constructor(address _bridgeAddress, address _relayer) {
        wormhole = IWormhole(_bridgeAddress);
        relayer = _relayer;
    }

    modifier onlyRelayerContract() {
        require(msg.sender == relayer, "msg.sender is not CoreRelayer contract.");
        _;
    }

    function receiveWormholeMessages(bytes[] memory whMessages, bytes[] memory)
        public
        payable
        override
        onlyRelayerContract
    {
        (Structs.VM memory vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(whMessages[0]);
        //validate
        require(valid, reason);
        // Ensure the emitterAddress of this VAA is the Uniswap message sender
        require(senderAdapters[vm.emitterChainId] == vm.emitterAddress, "Invalid Emitter Address!");
        //verify destination
        (address multiBridgeSendeer, address multiBridgeReceiver, bytes memory data, address receiverAdapter) = abi
            .decode(vm.payload, (address, address, bytes, address));
        require(receiverAdapter == address(this), "Message not for this dest");
        // replay protection
        bytes32 msgId = bytes32(uint256(vm.nonce));
        if (processedMessages[vm.hash]) {
            revert MessageIdAlreadyExecuted(msgId);
        } else {
            processedMessages[vm.hash] = true;
        }
        //send message to MultiBridgeReceiver
        (bool ok, bytes memory lowLevelData) = multiBridgeReceiver.call(
            abi.encodePacked(data, msgId, uint256(reverseIdMap[vm.emitterChainId]), multiBridgeSendeer)
        );
        if (!ok) {
            revert MessageFailure(msgId, lowLevelData);
        } else {
            emit MessageIdExecuted(reverseIdMap[vm.emitterChainId], msgId);
        }
    }

    function setChainIdMap(uint256[] calldata _origIds, uint16[] calldata _whIds) external onlyOwner {
        require(_origIds.length == _whIds.length, "mismatch length");
        for (uint256 i = 0; i < _origIds.length; i++) {
            idMap[_origIds[i]] = _whIds[i];
            reverseIdMap[_whIds[i]] = _origIds[i];
        }
    }

    function updateSenderAdapter(uint256[] calldata _srcChainIds, address[] calldata _senderAdapters)
        external
        override
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _srcChainIds.length; i++) {
            uint16 wormholeId = idMap[_srcChainIds[i]];
            require(wormholeId != 0, "unrecognized srcChainId");
            senderAdapters[wormholeId] = bytes32(uint256(uint160(_senderAdapters[i])));
            emit SenderAdapterUpdated(_srcChainIds[i], _senderAdapters[i]);
        }
    }
}
