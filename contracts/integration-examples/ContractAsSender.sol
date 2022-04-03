// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../libraries/BridgeTransferLib.sol";
import "../safeguard/Pauser.sol";

/**
 * @title Example contract to send cBridge transfers. Supports the liquidity pool-based {Bridge}, the {OriginalTokenVault} for pegged
 * deposit and the {PeggedTokenBridge} for pegged burn. Includes handling of refunds for failed transfers.
 */
contract ContractAsSender is ReentrancyGuard, Pauser {
    using SafeERC20 for IERC20;

    mapping(BridgeTransferLib.BridgeSendType => address) public bridges;
    mapping(bytes32 => address) public records;

    event Deposited(address depositor, address token, uint256 amount);
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
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeTransferLib.BridgeSendType _bridgeSendType
    ) external nonReentrant whenNotPaused onlyOwner returns (bytes32) {
        address _bridgeAddr = bridges[_bridgeSendType];
        require(_bridgeAddr != address(0), "unknown bridge type");
        bytes32 transferId = BridgeTransferLib.sendTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _bridgeSendType,
            _bridgeAddr
        );
        require(records[transferId] == address(0), "record exists");
        records[transferId] = msg.sender;
        return transferId;
    }

    /**
     * @notice Refund a failed cross-chain transfer.
     * @param _request The serialized request protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     * @param _bridgeSendType The type of bridge used by this failed transfer. One of the {BridgeSendType} enum.
     */
    function refund(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        BridgeTransferLib.BridgeSendType _bridgeSendType
    ) external nonReentrant whenNotPaused onlyOwner returns (bytes32) {
        address _bridgeAddr = bridges[_bridgeSendType];
        require(_bridgeAddr != address(0), "unknown bridge type");
        BridgeTransferLib.ReceiveInfo memory refundInfo = BridgeTransferLib.receiveTransfer(
            _request,
            _sigs,
            _signers,
            _powers,
            BridgeTransferLib.bridgeRefundType(_bridgeSendType),
            _bridgeAddr
        );
        require(refundInfo.receiver == address(this), "invalid refund");
        address _receiver = records[refundInfo.refid];
        require(_receiver != address(0), "unknown transfer id or already refunded");
        delete records[refundInfo.refid];
        IERC20(refundInfo.token).safeTransfer(_receiver, refundInfo.amount);
        return refundInfo.transferId;
    }

    /**
     * @notice Lock tokens.
     * @param _token The deposited token address.
     * @param _amount The amount to deposit.
     */
    function deposit(address _token, uint256 _amount) external nonReentrant whenNotPaused onlyOwner {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _token, _amount);
    }

    // ----------------------Admin operation-----------------------

    function setBridgeAddress(BridgeTransferLib.BridgeSendType _bridgeSendType, address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[_bridgeSendType] = _addr;
        emit BridgeUpdated(_bridgeSendType, _addr);
    }
}
