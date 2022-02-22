// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../libraries/BridgeSenderLib.sol";
import "../safeguard/Pauser.sol";

contract ContractAsSender is ReentrancyGuard, Pauser {
    using SafeERC20 for IERC20;

    mapping(BridgeSenderLib.BridgeType => address) public bridges;
    mapping(bytes32 => address) public records;

    event Deposited(address depositor, address token, uint256 amount);
    event LiquidityBridgeUpdated(address liquidityBridge);
    event PegBridgeUpdated(address pegBridge);
    event PegVaultUpdated(address pegVault);
    event PegBridgeV2Updated(address pegBridgeV2);
    event PegVaultV2Updated(address pegVaultV2);

    //    constructor(address _bridge, address _inbox) {
    //        bridge = _bridge;
    //        inbox = _inbox;
    //    }

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
     */
    function transfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeSenderLib.BridgeType _bridgeType
    ) external nonReentrant whenNotPaused onlyOwner returns (bytes32) {
        address _bridgeAddr = bridges[_bridgeType];
        require(_bridgeAddr != address(0), "unknown bridge type");
        bytes32 transferId = BridgeSenderLib.sendTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _bridgeType,
            _bridgeAddr
        );
        require(records[transferId] == address(0), "record exists");
        records[transferId] = msg.sender;
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
     */
    function refund(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers,
        BridgeSenderLib.BridgeType _bridgeType
    ) external nonReentrant whenNotPaused onlyOwner returns (bytes32) {
        address _bridgeAddr = bridges[_bridgeType];
        require(_bridgeAddr != address(0), "unknown bridge type");
        BridgeSenderLib.RefundInfo memory refundInfo = BridgeSenderLib.sendRefund(
            _request,
            _sigs,
            _signers,
            _powers,
            _bridgeType,
            _bridgeAddr
        );
        require(refundInfo.receiver == address(this), "invalid refund");
        require(records[refundInfo.refundId] == address(0), "already refunded");
        address _receiver = records[refundInfo.transferId];
        require(_receiver != address(0), "unknown transfer id");
        records[refundInfo.refundId] = _receiver;
        IERC20(refundInfo.token).safeTransfer(_receiver, refundInfo.amount);
        return refundInfo.refundId;
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

    function setLiquidityBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.Liquidity] = _addr;
        emit LiquidityBridgeUpdated(_addr);
    }

    function setPegBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegBurn] = _addr;
        emit PegBridgeUpdated(_addr);
    }

    function setPegVault(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegDeposit] = _addr;
        emit PegVaultUpdated(_addr);
    }

    function setPegBridgeV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegBurnV2] = _addr;
        emit PegBridgeV2Updated(_addr);
    }

    function setPegVaultV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegDepositV2] = _addr;
        emit PegVaultV2Updated(_addr);
    }
}
