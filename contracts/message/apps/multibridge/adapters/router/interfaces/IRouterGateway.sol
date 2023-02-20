// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Utils {
    struct RequestArgs {
        uint64 expTimestamp;
        bool isAtomicCalls;
        Utils.FeePayer feePayerEnum;
    }

    enum FeePayer {
        APP,
        USER,
        NONE
    }

    struct AckGasParams {
        uint64 gasLimit;
        uint64 gasPrice;
    }

    struct DestinationChainParams {
        uint64 gasLimit;
        uint64 gasPrice;
        uint64 destChainType;
        string destChainId;
    }

    struct ContractCalls {
        bytes[] payloads;
        bytes[] destContractAddresses;
    }

    enum AckType {
        NO_ACK,
        ACK_ON_SUCCESS,
        ACK_ON_ERROR,
        ACK_ON_BOTH
    }
}

interface IRouterGateway {
    /// @notice Function to send a message to the destination chain
    /// @param requestArgs the struct request args containing expiry timestamp, isAtomicCalls and the fee payer.
    /// @param ackType type of acknowledgement you want: ACK_ON_SUCCESS, ACK_ON_ERR, ACK_ON_BOTH.
    /// @param ackGasParams This includes the gas limit required for the execution of handler function for
    /// crosstalk acknowledgement on the source chain and the gas price of the source chain.
    /// @param destChainParams dest chain params include the destChainType, destChainId, the gas limit
    /// required to execute handler function on the destination chain and the gas price of destination chain.
    /// @param contractCalls Array of struct ContractCalls containing the multiple payloads to be sent to multiple
    /// contract addresses (in bytes format) on the destination chain.
    /// @return Returns the nonce from the gateway contract.
    function requestToDest(
        Utils.RequestArgs memory requestArgs,
        Utils.AckType ackType,
        Utils.AckGasParams memory ackGasParams,
        Utils.DestinationChainParams memory destChainParams,
        Utils.ContractCalls memory contractCalls
    ) external payable returns (uint64);

    /// @notice Function to fetch the fees for cross-chain message transfer.
    /// @return fees
    function requestToDestDefaultFee() external view returns (uint256 fees);
}
