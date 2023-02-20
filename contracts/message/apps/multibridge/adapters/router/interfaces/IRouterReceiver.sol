// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @dev Router Receiver Interface.
 */
interface IRouterReceiver {
    /// @notice Function to handle incoming cross-chain message.
    /// @param srcContractAddress address of contract on source chain where the request was initiated.
    /// @param payload abi encoded message sent from the source chain.
    /// @param srcChainId chainId of the source chain.
    /// @param srcChainType chainType of the source chain (0 for EVM).
    /// @return return value
    function handleRequestFromSource(
        bytes memory srcContractAddress,
        bytes memory payload,
        string memory srcChainId,
        uint64 srcChainType
    ) external returns (bytes memory);
}
