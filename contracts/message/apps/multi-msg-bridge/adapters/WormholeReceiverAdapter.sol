// SPDX-License-Identifier: Apache 2

pragma solidity >=0.8.9;

import "../MessageStruct.sol";
import "../IMultiMsgReceiver.sol";

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

contract WormholeReceiverAdapter {
    bytes32 public immutable senderAdapter;
    address public immutable multiMsgReceiver;
    IWormhole private immutable wormhole;
    mapping(bytes32 => bool) public processedMessages;

    constructor(
        address _multiMsgReceiver,
        address _bridgeAddress,
        bytes32 _senderAdapter
    ) {
        multiMsgReceiver = _multiMsgReceiver;
        wormhole = IWormhole(_bridgeAddress);
        senderAdapter = _senderAdapter;
    }

    function receiveMessage(bytes[] memory whMessages) public {
        (Structs.VM memory vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(whMessages[0]);

        //validate
        require(valid, reason);

        // Ensure the emitterAddress of this VAA is the Uniswap message sender
        require(senderAdapter == vm.emitterAddress, "Invalid Emitter Address!");

        //verify destination
        (MessageStruct.Message memory message, address receiverAdapter) = abi.decode(
            vm.payload,
            (MessageStruct.Message, address)
        );
        require(receiverAdapter == address(this), "Message not for this dest");

        // replay protection
        require(!processedMessages[vm.hash], "Message already processed");
        processedMessages[vm.hash] = true;

        //send message to MultiMsgReceiver
        IMultiMsgReceiver(multiMsgReceiver).receiveMessage(message);
    }
}
