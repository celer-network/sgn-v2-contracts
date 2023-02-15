// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./MessageDispatcher.sol";

/**
 * @dev The SingleMessageDispatcher is an extension of MessageDispatcher that defines a method, dispatchMessage,
 * for dispatching an individual message to be executed on the toChainId.
 * More about SingleMessageDispatcher of EIP5164, see https://eips.ethereum.org/EIPS/eip-5164#singlemessagedispatcher.
 */
interface SingleMessageDispatcher is MessageDispatcher {
    /**
     * @dev A method for dispatching an individual message to be executed on the toChainId.
     */
    function dispatchMessage(
        uint256 toChainId,
        address to,
        bytes calldata data
    ) external payable returns (bytes32 messageId);
}
