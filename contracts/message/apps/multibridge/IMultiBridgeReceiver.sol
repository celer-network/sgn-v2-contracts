// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./MessageStruct.sol";

interface IMultiBridgeReceiver {
    function receiveMessage(MessageStruct.Message calldata _message) external;
}
