// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./MessageStruct.sol";

interface ISenderAdapter {
    function getMessageFee(MessageStruct.Message memory _message) external view returns (uint256);

    function sendMessage(MessageStruct.Message memory _message) external payable;
}
