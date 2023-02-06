// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../../MessageStruct.sol";

interface IDeBridgeReceiverAdapter {

    function executeMessage(
        MessageStruct.Message memory _message
    ) external;
}
