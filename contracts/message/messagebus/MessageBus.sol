// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(
        ISigsVerifier _sigsVerifier,
        address _liquidityBridge,
        address _pegBridge,
        address _pegVault
    ) MessageBusSender(_sigsVerifier) {}

    // this is only to be called by Proxy via delegateCall as initOwner will require _owner is 0.
    // so calling init on this contract directly will guarantee to fail
    function init() external {
        // MUST manually call ownable init and must only call once
        initOwner();
    }
}
