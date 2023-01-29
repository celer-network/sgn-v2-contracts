// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./MessageStruct.sol";

interface IMultiMsgReceiver {
    function receiveMessage(MessageStruct.Message calldata _message) external;
}
