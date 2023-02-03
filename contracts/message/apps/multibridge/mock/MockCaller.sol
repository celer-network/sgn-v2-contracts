// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../MessageStruct.sol";
import "../MultiBridgeSender.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockCaller is AccessControl {
    bytes32 public constant CALLER_ROLE = keccak256("CALLER");
    MultiBridgeSender public bridgeSender;

    error AdminBadRole();
    error CallerBadRole();

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert AdminBadRole();
        _;
    }

    modifier onlyCaller() {
        if (!hasRole(CALLER_ROLE, msg.sender)) revert CallerBadRole();
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setMultiBridgeSender(MultiBridgeSender _bridgeSender) external onlyAdmin {
        bridgeSender = _bridgeSender;
    }

    function remoteCall(
        uint64 _dstChainId,
        address _target,
        bytes calldata _callData
    ) external payable onlyCaller {
        bridgeSender.remoteCall{value: msg.value}(_dstChainId, _target, _callData);
    }

    function addSenderAdapters(address[] calldata _senderAdapters) external onlyAdmin {
       bridgeSender.addSenderAdapters(_senderAdapters);
    }

    function removeSenderAdapters(address[] calldata _senderAdapters) external onlyAdmin {
        bridgeSender.removeSenderAdapters(_senderAdapters);
    }
}
