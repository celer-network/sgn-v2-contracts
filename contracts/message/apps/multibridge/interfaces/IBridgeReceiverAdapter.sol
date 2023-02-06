// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

/**
 * @dev Adapter that connects MultiBridgeReceiver and each message bridge.
 */
interface IBridgeReceiverAdapter {
    /**
     * @dev Owner update sender adapter address on src chain.
     */
    function updateSenderAdapter(uint64[] calldata _srcChainIds, address[] calldata _senderAdapters) external;

    /**
     * @dev Owner setup MultiBridgeReceiver.
     */
    function setMultiBridgeReceiver(address _multiBridgeReceiver) external;
}