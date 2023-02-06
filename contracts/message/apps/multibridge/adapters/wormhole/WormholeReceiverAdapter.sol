// SPDX-License-Identifier: Apache 2

pragma solidity >=0.8.9;

import "../../MessageStruct.sol";
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
    mapping(uint64 => uint16) idMap;
    mapping(uint16 => bytes32) public senderAdapters;
    address public multiBridgeReceiver;
    IWormhole private immutable wormhole;
    address private immutable relayer;
    mapping(bytes32 => bool) public processedMessages;

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
        (MessageStruct.Message memory message, address receiverAdapter) = abi.decode(
            vm.payload,
            (MessageStruct.Message, address)
        );
        require(receiverAdapter == address(this), "Message not for this dest");
        // replay protection
        require(!processedMessages[vm.hash], "Message already processed");
        processedMessages[vm.hash] = true;
        //send message to MultiBridgeReceiver
        IMultiBridgeReceiver(multiBridgeReceiver).receiveMessage(message);
    }

    function setChainIdMap(uint64[] calldata _origIds, uint16[] calldata _whIds) external onlyOwner {
        require(_origIds.length == _whIds.length, "mismatch length");
        for (uint256 i = 0; i < _origIds.length; i++) {
            idMap[_origIds[i]] = _whIds[i];
        }
    }

    function updateSenderAdapter(uint64[] calldata _srcChainIds, address[] calldata _senderAdapters)
        external
        override
        onlyOwner
    {
        require(_srcChainIds.length == _senderAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _srcChainIds.length; i++) {
            uint16 wormholeId = idMap[_srcChainIds[i]];
            require(wormholeId != 0, "unrecognized srcChainId");
            senderAdapters[wormholeId] = bytes32(uint256(uint160(_senderAdapters[i])));
        }
    }

    function setMultiBridgeReceiver(address _multiBridgeReceiver) external override onlyOwner {
        multiBridgeReceiver = _multiBridgeReceiver;
    }
}
