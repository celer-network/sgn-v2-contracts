// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./PbBridge.sol";
import "./PbPegged.sol";
import "./PbPool.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IOriginalTokenVault.sol";
import "../interfaces/IOriginalTokenVaultV2.sol";
import "../interfaces/IPeggedTokenBridge.sol";
import "../interfaces/IPeggedTokenBridgeV2.sol";
import "../interfaces/IPool.sol";

library BridgeSenderLib {
    using SafeERC20 for IERC20;

    struct RefundInfo {
        bytes32 transferId;
        address receiver;
        address token;
        uint256 amount;
        bytes32 refundId;
    }

    enum BridgeSendType {
        Null,
        Liquidity,
        PegDeposit,
        PegBurn,
        PegV2Deposit,
        PegV2Burn,
        PegV2BurnFrom
    }

    // ============== Internal library functions called by apps ==============

    /**
     * @notice Send a cross-chain transfer either via liquidity pool-based bridge or in the form of pegged mint / burn.
     * @param _receiver The address of the receiver.
     * @param _token The address of the token.
     * @param _amount The amount of the transfer.
     * @param _dstChainId The destination chain ID.
     * @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
     * @param _maxSlippage (optional, only used for transfer via liquidity pool-based bridge)
     * The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
     * Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least (100% - max slippage percentage) * amount or the
     * transfer can be refunded.
     * @param _bridgeSendType The type of the bridge used by this transfer. One of the {BridgeSendType} enum.
     * @param _bridgeAddr The address of the bridge used.
     */
    function sendTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeSendType _bridgeSendType,
        address _bridgeAddr
    ) internal returns (bytes32) {
        bytes32 transferId;
        IERC20(_token).safeIncreaseAllowance(_bridgeAddr, _amount);
        if (_bridgeSendType == BridgeSendType.Liquidity) {
            IBridge(_bridgeAddr).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
            transferId = keccak256(
                abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
            );
        } else if (_bridgeSendType == BridgeSendType.PegDeposit) {
            IOriginalTokenVault(_bridgeAddr).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _dstChainId, _receiver, _nonce, uint64(block.chainid))
            );
        } else if (_bridgeSendType == BridgeSendType.PegBurn) {
            IPeggedTokenBridge(_bridgeAddr).burn(_token, _amount, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _receiver, _nonce, uint64(block.chainid))
            );
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(_bridgeAddr, 0);
        } else if (_bridgeSendType == BridgeSendType.PegV2Deposit) {
            transferId = IOriginalTokenVaultV2(_bridgeAddr).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
        } else if (_bridgeSendType == BridgeSendType.PegV2Burn) {
            transferId = IPeggedTokenBridgeV2(_bridgeAddr).burn(_token, _amount, _dstChainId, _receiver, _nonce);
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(_bridgeAddr, 0);
        } else if (_bridgeSendType == BridgeSendType.PegV2BurnFrom) {
            transferId = IPeggedTokenBridgeV2(_bridgeAddr).burnFrom(_token, _amount, _dstChainId, _receiver, _nonce);
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(_bridgeAddr, 0);
        } else {
            revert("bridge type not supported");
        }
        return transferId;
    }

    /**
     * @notice Refund a failed cross-chain transfer.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeSendType The type of the bridge used by this failed transfer. One of the {BridgeSendType} enum.
     * @param _bridgeAddr The address of the bridge used.
     */
    function sendRefund(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        BridgeSendType _bridgeSendType,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        if (_bridgeSendType == BridgeSendType.Liquidity) {
            return sendRefundForLiquidityBridgeTransfer(_request, _sigs, _signers, _powers, _bridgeAddr);
        } else if (_bridgeSendType == BridgeSendType.PegDeposit) {
            return sendRefundForPegVaultDeposit(_request, _sigs, _signers, _powers, _bridgeAddr);
        } else if (_bridgeSendType == BridgeSendType.PegBurn) {
            return sendRefundForPegBridgeBurn(_request, _sigs, _signers, _powers, _bridgeAddr);
        } else if (_bridgeSendType == BridgeSendType.PegV2Deposit) {
            return sendRefundForPegVaultV2Deposit(_request, _sigs, _signers, _powers, _bridgeAddr);
        } else if (_bridgeSendType == BridgeSendType.PegV2Burn) {
            return sendRefundForPegBridgeV2Burn(_request, _sigs, _signers, _powers, _bridgeAddr);
        } else {
            revert("bridge type not supported");
        }
    }

    /**
     * @notice Refund a failed cross-chain transfer which used liquidity bridge.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeAddr The address of liquidity bridge.
     */
    function sendRefundForLiquidityBridgeTransfer(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        RefundInfo memory refund;
        PbPool.WithdrawMsg memory request = PbPool.decWithdrawMsg(_request);
        // len = 8 + 8 + 20 + 20 + 32 = 88
        refund.refundId = keccak256(
            abi.encodePacked(request.chainid, request.seqnum, request.receiver, request.token, request.amount)
        );
        refund.transferId = request.refid;
        refund.receiver = request.receiver;
        refund.token = request.token;
        refund.amount = request.amount;
        if (!IPool(_bridgeAddr).withdraws(refund.refundId)) {
            IPool(_bridgeAddr).withdraw(_request, _sigs, _signers, _powers);
        }
        return refund;
    }

    /**
     * @notice Refund a failed cross-chain transfer which is an OriginalTokenVault deposit.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeAddr The address of OriginalTokenVault.
     */
    function sendRefundForPegVaultDeposit(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        RefundInfo memory refund;
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        refund.refundId = keccak256(
            // len = 20 + 20 + 32 + 20 + 8 + 32 = 132
            abi.encodePacked(
                request.receiver,
                request.token,
                request.amount,
                request.burnAccount,
                request.refChainId,
                request.refId
            )
        );
        refund.transferId = request.refId;
        refund.receiver = request.receiver;
        refund.token = request.token;
        refund.amount = request.amount;
        if (!IOriginalTokenVault(_bridgeAddr).records(refund.refundId)) {
            IOriginalTokenVault(_bridgeAddr).withdraw(_request, _sigs, _signers, _powers);
        }
        return refund;
    }

    /**
     * @notice Refund a failed cross-chain transfer which is an PeggedTokenBridge burn.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeAddr The address of PeggedTokenBridge.
     */
    function sendRefundForPegBridgeBurn(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        RefundInfo memory refund;
        PbPegged.Mint memory request = PbPegged.decMint(_request);
        refund.refundId = keccak256(
            // len = 20 + 20 + 32 + 20 + 8 + 32 = 132
            abi.encodePacked(
                request.account,
                request.token,
                request.amount,
                request.depositor,
                request.refChainId,
                request.refId
            )
        );
        refund.transferId = request.refId;
        refund.receiver = request.account;
        refund.token = request.token;
        refund.amount = request.amount;
        if (!IPeggedTokenBridge(_bridgeAddr).records(refund.refundId)) {
            IPeggedTokenBridge(_bridgeAddr).mint(_request, _sigs, _signers, _powers);
        }
        return refund;
    }

    /**
     * @notice Refund a failed cross-chain transfer which is an OriginalTokenVaultV2 deposit.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeAddr The address of OriginalTokenVaultV2.
     */
    function sendRefundForPegVaultV2Deposit(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        RefundInfo memory refund;
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        if (IOriginalTokenVaultV2(_bridgeAddr).records(request.refId)) {
            refund.refundId = keccak256(
                // len = 20 + 20 + 32 + 20 + 8 + 32 + 20 = 152
                abi.encodePacked(
                    request.receiver,
                    request.token,
                    request.amount,
                    request.burnAccount,
                    request.refChainId,
                    request.refId,
                    _bridgeAddr
                )
            );
        } else {
            refund.refundId = IOriginalTokenVaultV2(_bridgeAddr).withdraw(_request, _sigs, _signers, _powers);
        }
        refund.transferId = request.refId;
        refund.receiver = request.receiver;
        refund.token = request.token;
        refund.amount = request.amount;
        return refund;
    }

    /**
     * @notice Refund a failed cross-chain transfer which is an PeggedTokenBridgeV2 burn.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A request must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeAddr The address of PeggedTokenBridgeV2.
     */
    function sendRefundForPegBridgeV2Burn(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        address _bridgeAddr
    ) internal returns (RefundInfo memory) {
        RefundInfo memory refund;
        PbPegged.Mint memory request = PbPegged.decMint(_request);
        if (IPeggedTokenBridgeV2(_bridgeAddr).records(request.refId)) {
            refund.refundId = keccak256(
                // len = 20 + 20 + 32 + 20 + 8 + 32 + 20 = 152
                abi.encodePacked(
                    request.account,
                    request.token,
                    request.amount,
                    request.depositor,
                    request.refChainId,
                    request.refId,
                    _bridgeAddr
                )
            );
        } else {
            refund.refundId = IPeggedTokenBridgeV2(_bridgeAddr).mint(_request, _sigs, _signers, _powers);
        }
        refund.transferId = request.refId;
        refund.receiver = request.account;
        refund.token = request.token;
        refund.amount = request.amount;
        return refund;
    }
}
