// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

/**
 * @dev The MessageExecutor executes dispatched messages and message batches.
 *
 * MessageExecutor MUST append the ABI-packed (messageId, fromChainId, from) to the calldata for each message
 * being executed. This allows the receiver of the message to verify the cross-chain sender and the chain that
 * the message is coming from.
 * ```
 * to.call(abi.encodePacked(data, messageId, fromChainId, from));
 * ```
 *
 * More about MessageExecutor of EIP5164, see https://eips.ethereum.org/EIPS/eip-5164#messageexecutor.
 */
interface MessageExecutor {
    /**
     * @dev MessageExecutor MUST revert if a messageId has already been executed and SHOULD emit a
     * MessageIdAlreadyExecuted custom error.
     */
    error MessageIdAlreadyExecuted(bytes32 messageId);

    /**
     * @dev MessageExecutor MUST revert if an individual message fails and SHOULD emit a MessageFailure custom error.
     */
    error MessageFailure(bytes32 messageId, bytes errorData);

    /**
     * @dev MessageExecutor MUST revert the entire batch if any message in a batch fails and SHOULD emit a
     * MessageBatchFailure custom error.
     */
    error MessageBatchFailure(bytes32 messageId, uint256 messageIndex, bytes errorData);

    /**
     * @dev MessageIdExecuted MUST be emitted once a message or message batch has been executed.
     */
    event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);
}
