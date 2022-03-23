// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

library DataTypes {
    struct RefundParams {
        bytes message;
        TransferInfo transfer;
        bytes[] sigs;
        address[] signers;
        uint256[] powers;
    }
    enum BridgeType {
        Null,
        Liquidity,
        PegDeposit,
        PegBurn,
        PegDepositV2,
        PegBurnV2
    }
    enum TransferType {
        Null,
        LqSend, // send through liquidity bridge
        LqWithdraw, // withdraw from liquidity bridge
        PegMint, // mint through pegged token bridge
        PegWithdraw, // withdraw from original token vault
        PegMintV2, // mint through pegged token bridge v2
        PegWithdrawV2 // withdraw from original token vault v2
    }
    enum MsgType {
        MessageWithTransfer,
        MessageOnly
    }
    struct TransferInfo {
        TransferType t;
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint64 wdseq; // only needed for LqWithdraw (refund)
        uint64 srcChainId;
        bytes32 refId;
        bytes32 srcTxHash; // src chain msg tx hash
    }
    struct RouteInfo {
        address sender;
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash; // src chain msg tx hash
    }
    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback,
        Pending
    }
}
