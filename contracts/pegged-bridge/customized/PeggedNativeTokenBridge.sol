// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../PeggedTokenBridgeV2.sol";

interface INativeVault {
    function burn() external payable;
}

contract PeggedNativeTokenBridge is PeggedTokenBridgeV2 {
    // native vault address is treated as the pegged natvie token address
    address public nativeVault;

    constructor(ISigsVerifier _sigsVerifier) PeggedTokenBridgeV2(_sigsVerifier) {}

    function burnNative(
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external payable whenNotPaused returns (bytes32) {
        require(msg.value > 0, "zero msg value");
        bytes32 burnId = _burn(nativeVault, msg.value, _toChainId, _toAccount, _nonce);
        INativeVault(nativeVault).burn{value: msg.value}();
        return burnId;
    }

    function setNativeVault(address _natvieVault) external onlyOwner {
        nativeVault = _natvieVault;
    }
}
