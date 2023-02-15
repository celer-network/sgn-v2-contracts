// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

/**
 * @dev The MessageDispatcher lives on the origin chain and dispatches messages to the MessageExecutor for execution.
 * More about MessageDispatcher of EIP5164, see https://eips.ethereum.org/EIPS/eip-5164#messagedispatcher.
 */
interface MessageDispatcher {
    /**
     * @dev The MessageDispatched event MUST be emitted by the MessageDispatcher when an individual message is dispatched.
     */
    event MessageDispatched(
        bytes32 indexed messageId,
        address indexed from,
        uint256 indexed toChainId,
        address to,
        bytes data
    );
}
