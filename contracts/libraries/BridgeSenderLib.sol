// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./PbPegged.sol";
import "./PbBridge.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IOriginalTokenVault.sol";
import "../interfaces/IOriginalTokenVaultV2.sol";
import "../interfaces/IPeggedTokenBridge.sol";
import "../interfaces/IPeggedTokenBridgeV2.sol";

library BridgeSenderLib {
    using SafeERC20 for IERC20;

    enum BridgeType {
        Null,
        Liquidity,
        PegDeposit,
        PegBurn,
        PegDepositV2,
        PegBurnV2
    }

    // ============== Internal library functions called by apps ==============

    /**
     * @notice Send a cross-chain transfer either via liquidity pool-based bridge or in form of mint/burn.
     * @param _receiver The address of the receiver.
     * @param _token The address of the token.
     * @param _amount The amount of the transfer.
     * @param _dstChainId The destination chain ID.
     * @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
     * @param _maxSlippage (optional, only used for transfer via liquidity pool-based bridge)
     * The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
     * Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least (100% - max slippage percentage) * amount or the
     * transfer can be refunded.
     * @param _bridgeType The type of bridge used by this transfer. One of the {BridgeType} enum.
     * @param _bridgeAddr The address of used bridge.
     */
    function sendTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeType _bridgeType,
        address _bridgeAddr
    ) internal returns (bytes32 memory) {
        bytes32 memory transferId;
        if (_bridgeType == BridgeType.Liquidity) {
            IERC20(_token).safeIncreaseAllowance(_bridgeAddr, _amount);
            IBridge(_bridgeAddr).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
            transferId = keccak256(
                abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
            );
        } else if (_bridgeType == BridgeType.PegDeposit) {
            IERC20(_token).safeIncreaseAllowance(_bridgeAddr, _amount);
            IOriginalTokenVault(_bridgeAddr).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _dstChainId, _receiver, _nonce, uint64(block.chainid))
            );
        } else if (_bridgeType == BridgeType.PegBurn) {
            IPeggedTokenBridge(_bridgeAddr).burn(_token, _amount, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _receiver, _nonce, uint64(block.chainid))
            );
        } else if (_bridgeType == BridgeType.PegDepositV2) {
            IERC20(_token).safeIncreaseAllowance(_bridgeAddr, _amount);
            transferId = IOriginalTokenVaultV2(_bridgeAddr).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
        } else if (_bridgeType == BridgeType.PegBurnV2) {
            transferId = IPeggedTokenBridgeV2(_bridgeAddr).burn(_token, _amount, _dstChainId, _receiver, _nonce);
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
     * @param _bridgeType The type of bridge used by this failed transfer. One of the {BridgeType} enum.
     * @param _bridgeAddr The address of used bridge.
     */
    function sendRefund(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        BridgeType _bridgeType,
        address _bridgeAddr
    ) internal returns (bytes32, address, uint256, bytes32) {
        if (_bridgeType == BridgeType.Liquidity) {
            PbBridge.Relay memory request = PbBridge.decRelay(_request);
            require(request.receiver == address(this), "invalid refund");
            // len = 20 + 20 + 20 + 32 + 8 + 8 + 32 = 140
            bytes32 refundId = keccak256(
                abi.encodePacked(
                    request.sender,
                    request.receiver,
                    request.token,
                    request.amount,
                    request.srcChainId,
                    request.dstChainId,
                    request.srcTransferId
                )
            );
            IBridge(_bridgeAddr).relay(_request, _sigs, _signers, _powers);
            return (request.srcTransferId, request.token, request.amount, refundId);
        } else if (_bridgeType == BridgeType.PegDeposit) {
            PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
            require(request.receiver == address(this), "invalid refund");
            bytes32 refundId = keccak256(
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
            IOriginalTokenVault(_bridgeAddr).withdraw(_request, _sigs, _signers, _powers);
            return (request.refId, request.token, request.amount, refundId);
        } else if (_bridgeType == BridgeType.PegBurn) {
            PbPegged.Mint memory request = PbPegged.decMint(_request);
            require(request.account == address(this), "invalid refund");
            bytes32 refundId = keccak256(
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
            IPeggedTokenBridge(_bridgeAddr).mint(_request, _sigs, _signers, _powers);
            return (request.refId, request.token, request.amount, refundId);
        } else if (_bridgeType == BridgeType.PegDepositV2) {
            PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
            require(request.receiver == address(this), "invalid refund");
            bytes32 refundId = IOriginalTokenVaultV2(_bridgeAddr).withdraw(_request, _sigs, _signers, _powers);
            return (request.refId, request.token, request.amount, refundId);
        } else if (_bridgeType == BridgeType.PegBurnV2) {
            PbPegged.Mint memory request = PbPegged.decMint(_request);
            require(request.account == address(this), "invalid refund");
            bytes32 refundId = IPeggedTokenBridgeV2(_bridgeAddr).mint(_request, _sigs, _signers, _powers);
            return (request.refId, request.token, request.amount, refundId);
        } else {
            revert("bridge type not supported");
        }
    }
}
