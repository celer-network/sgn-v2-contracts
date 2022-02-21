// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../libraries/BridgeSenderLib.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IWithdrawInbox.sol";
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
     * @param _bridgeAddr The address of used bridge.
     */
    function transfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage, // slippage * 1M, eg. 0.5% -> 5000
        BridgeSenderLib.BridgeType _bridgeType
    ) external nonReentrant whenNotPaused returns (bytes32) {
        address _bridge = bridges[_bridgeType];
        require(_bridge != address(0), "unknown bridge type");
        bytes32 transferId = BridgeSenderLib.sendTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _bridgeType,
            _bridge
        );
        require(records[transferId] == address(0), "record exists");
        records[transferId] = msg.sender;
        return transferId;
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

    /**
     * @notice Add liquidity to the pool-based bridge.
     * NOTE: This function DOES NOT SUPPORT fee-on-transfer / rebasing tokens.
     * @param _token The address of the token.
     * @param _amount The amount to add.
     */
    function addLiquidity(address _token, uint256 _amount) external whenNotPaused onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "insufficient balance");
        IERC20(_token).safeIncreaseAllowance(bridge, _amount);
        IPool(bridge).addLiquidity(_token, _amount);
    }

    /**
     * @notice Withdraw liquidity from the pool-based bridge.
     * NOTE: Each of your withdrawal request should have different _wdSeq.
     * NOTE: Tokens to withdraw within one withdrawal request should have the same symbol.
     * @param _wdSeq The unique sequence number to identify this withdrawal request.
     * @param _receiver The receiver address on _toChain.
     * @param _toChain The chain Id to receive the withdrawn tokens.
     * @param _fromChains The chain Ids to withdraw tokens.
     * @param _tokens The token to withdraw on each fromChain.
     * @param _ratios The withdrawal ratios of each token.
     * @param _slippages The max slippages of each token for cross-chain withdraw.
     */
    function withdraw(
        uint64 _wdSeq,
        address _receiver,
        uint64 _toChain,
        uint64[] calldata _fromChains,
        address[] calldata _tokens,
        uint32[] calldata _ratios,
        uint32[] calldata _slippages
    ) external whenNotPaused onlyOwner {
        IWithdrawInbox(inbox).withdraw(_wdSeq, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
    }


    // ----------------------Admin operation-----------------------
    function setBridge(address _bridge) external onlyOwner {
        bridges[_bridgeType] = _bridge;
        emit BridgeUpdated();
    }

    function setLiquidityBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.Liquidity] = _addr;
        emit LiquidityBridgeUpdated(liquidityBridge);
    }

    function setPegBridge(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegBurn] = _addr;
        emit PegBridgeUpdated(pegBridge);
    }

    function setPegVault(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegDeposit] = _addr;
        emit PegVaultUpdated(pegVault);
    }

    function setPegBridgeV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegBurnV2] = _addr;
        emit PegBridgeV2Updated(pegBridgeV2);
    }

    function setPegVaultV2(address _addr) public onlyOwner {
        require(_addr != address(0), "invalid address");
        bridges[BridgeSenderLib.BridgeType.PegDepositV2] = _addr;
        emit PegVaultV2Updated(pegVaultV2);
    }
}
