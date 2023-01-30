// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../MessageStruct.sol";

interface IMultiBridgeReceiver {
    /**
     * @notice Receive MessageStruct.Message from allowed receiverAdapter of message bridge.
     * This function call only be called once for each message by each allowed receiverAdapter.
     *
     * During function call, if the accumulated power of this message has reached or exceeded
     * the power threshold, this message will be executed immediately.
     *
     * Message execution would result in a solidity external message call, which has two possible type of target:
     * 1. other contract for whatever purpose;
     * 2. this contract for sake of adjusting params like receiverAdaptersPower or powerThreshold.
     *
     * @dev Every receiver adapter should call this function with well decoded MessageStruct.Message
     * when receiver adapter receives a message produced by corresponding sender adapter on source chain.
     */
    function receiveMessage(MessageStruct.Message calldata _message) external;
}
