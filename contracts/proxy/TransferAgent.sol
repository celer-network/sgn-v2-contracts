// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../libraries/BridgeTransferLib.sol";
import "../safeguard/Pauser.sol";

/**
 * @title Transfer agent. Designed to support arbitrary length receiver address for transfer. Supports the liquidity pool-based {Bridge}, the {OriginalTokenVault} for pegged
 * deposit and the {PeggedTokenBridge} for pegged burn. Supports contract sender as well.
 */
contract TransferAgent is ReentrancyGuard, Pauser {
    using SafeERC20 for IERC20;

    mapping(BridgeTransferLib.BridgeSendType => address) public bridges;

    event Supplement(bytes32 transferId, address sender, bytes receiver);
    event BridgeUpdated(BridgeTransferLib.BridgeSendType bridgeSendType, address bridgeAddr);

    /**
     * @notice Send a cross-chain transfer either via liquidity pool-based bridge or in form of mint/burn.
     * @param _receiver The address of the receiver.
     * @param _token The address of the token.
     * @param _amount The amount of the transfer.
     * @param _dstChainId The destination chain ID.
     * @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
     * @param _maxSlippage The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
     *        Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least
     *        (100% - max slippage percentage) * amount or the transfer can be refunded.
     *        Only applicable to the {BridgeSendType.Liquidity}.
     * @param _bridgeSendType The type of bridge used by this transfer. One of the {BridgeSendType} enum.
     */
    function transfer(
        bytes calldata _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeTransferLib.BridgeSendType _bridgeSendType
    ) external nonReentrant whenNotPaused returns (bytes32) {
        address _bridgeAddr = bridges[_bridgeSendType];
        require(_bridgeAddr != address(0), "unknown bridge type");
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes32 transferId = BridgeTransferLib.sendTransfer(
            address(0),
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _bridgeSendType,
            _bridgeAddr
        );
        emit Supplement(transferId, msg.sender, _receiver);
        return transferId;
    }

    // ----------------------Admin operation-----------------------

    function setBridgeAddress(BridgeTransferLib.BridgeSendType _bridgeSendType, address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[_bridgeSendType] = _addr;
        emit BridgeUpdated(_bridgeSendType, _addr);
    }
}
