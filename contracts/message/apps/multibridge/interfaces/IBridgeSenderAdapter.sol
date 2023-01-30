// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../MessageStruct.sol";

/**
 * @dev Contract interface which should be implemented by any message bridge.
 *
 * Message bridge can implement their favourite encode&decode way for MessageStruct.Message.
 */
interface IBridgeSenderAdapter {
    /**
     * @dev Return native token amount in wei required by this message bridge for sending a MessageStruct.Message.
     */
    function getMessageFee(MessageStruct.Message memory _message) external view returns (uint256);

    /**
     * @dev Send a MessageStruct.Message through this message bridge.
     */
    function sendMessage(MessageStruct.Message memory _message) external payable;
}
