// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../MessageStruct.sol";

/**
 * @dev Adapter that connects MultiBridgeSender and each message bridge.
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

    /**
     * @dev Owner update receiver adapter address on dst chain.
     */
    function updateReceiverAdapter(uint64[] calldata _dstChainIds, address[] calldata _receiverAdapters) external;

    /**
     * @dev Owner setup MultiBridgeSender.
     */
    function setMultiBridgeSender(address _multiBridgeSender) external;
}
