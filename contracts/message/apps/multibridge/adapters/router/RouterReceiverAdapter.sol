// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IMultiBridgeReceiver.sol";
import "../../interfaces/IBridgeReceiverAdapter.sol";
import "./interfaces/IRouterGateway.sol";
import "./interfaces/IRouterReceiver.sol";
import "./libraries/StringToUint.sol";

contract RouterReceiverAdapter is Pausable, Ownable, IRouterReceiver, IBridgeReceiverAdapter {
    /* ========== STATE VARIABLES ========== */

    mapping(uint256 => address) public senderAdapters;
    IRouterGateway public immutable routerGateway;
    mapping(bytes32 => bool) public executedMessages;

    /* ========== MODIFIERS ========== */

    modifier onlyRouterGateway() {
        require(msg.sender == address(routerGateway), "caller is not router gateway");
        _;
    }

    /* ========== CONSTRUCTOR  ========== */

    constructor(address _routerGateway) {
        routerGateway = IRouterGateway(_routerGateway);
    }

    /* ========== EXTERNAL METHODS ========== */

    // Called by the Router Gateway on destination chain to receive cross-chain messages.
    // srcContractAddress is the address of contract on the source chain where the request was intiated
    // The payload is abi.encode of (MessageStruct.Message).
    function handleRequestFromSource(
        bytes memory srcContractAddress,
        bytes memory payload,
        string memory srcChainId,
        uint64 //srcChainType
    ) external override onlyRouterGateway whenNotPaused returns (bytes memory) {
        (address _multiBridgeSender, address _multiBridgeReceiver, bytes memory _data, bytes32 _msgId) = abi.decode(
            payload,
            (address, address, bytes, bytes32)
        );

        uint256 _sourceChainId = StringToUint.st2num(srcChainId);

        require(toAddress(srcContractAddress) == senderAdapters[_sourceChainId], "not allowed message sender");

        if (executedMessages[_msgId]) {
            revert MessageIdAlreadyExecuted(_msgId);
        } else {
            executedMessages[_msgId] = true;
        }

        (bool ok, bytes memory lowLevelData) = _multiBridgeReceiver.call(
            abi.encodePacked(_data, _msgId, _sourceChainId, _multiBridgeSender)
        );

        if (!ok) {
            revert MessageFailure(_msgId, lowLevelData);
        } else {
            emit MessageIdExecuted(_sourceChainId, _msgId);
        }

        return "";
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

    /* ========== UTILS METHODS ========== */

    function toAddress(bytes memory _bytes) internal pure returns (address contractAddress) {
        bytes20 srcTokenAddress;
        assembly {
            srcTokenAddress := mload(add(_bytes, 0x20))
        }
        contractAddress = address(srcTokenAddress);
    }
}
