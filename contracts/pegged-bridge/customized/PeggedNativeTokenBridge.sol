// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "../PeggedTokenBridgeV2.sol";

interface INativeWrap {
    function burn() external payable;
}

contract PeggedNativeTokenBridge is PeggedTokenBridgeV2 {
    address public nativeWrap;

    constructor(ISigsVerifier _sigsVerifier) PeggedTokenBridgeV2(_sigsVerifier) {}

    function burnNative(
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external payable whenNotPaused returns (bytes32) {
        require(msg.value > 0, "zero amount");
        bytes32 burnId = _burn(nativeWrap, msg.value, _toChainId, _toAccount, _nonce);
        INativeWrap(nativeWrap).burn{value: msg.value}();
        return burnId;
    }

    function setNativeWrap(address _natvieWrap) external onlyOwner {
        nativeWrap = _natvieWrap;
    }
}
