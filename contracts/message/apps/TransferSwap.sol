// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";
import "../../interfaces/IUniswapV2.sol";

contract TransferSwap is MsgSenderApp, MsgReceiverApp {
    using SafeERC20 for IERC20;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Not EOA");
        _;
    }

    struct SwapInfo {
        // if this array has only one element, it means no need to swap
        address[] path;
        // only needed if path.length > 1
        address dex;
        uint256 deadline;
        uint256 minRecvAmt;
    }

    struct SwapRequest {
        SwapInfo swap;
        address receiver;
        uint64 nonce;
    }

    enum SwapStatus {
        Null,
        Succeeded,
        Failed,
        Fallback
    }

    // emitted when requested dstChainId == srcChainId, no bridging
    event DirectSwap(
        bytes32 id,
        uint64 srcChainId,
        uint256 amountIn,
        address tokenIn,
        uint256 amountOut,
        address tokenOut
    );
    event SwapRequestSent(bytes32 id, uint64 dstChainId, uint256 srcAmount, address srcToken, address dstToken);
    event SwapRequestDone(bytes32 id, uint256 dstAmount, SwapStatus status);

    mapping(address => uint256) public minSwapAmounts;
    mapping(address => bool) supportedDex;
    uint64 nonce;

    constructor(address _msgbus) {
        msgBus = _msgbus;
    }

    /**
     * @notice Sends a cross-chain transfer via the liquidity pool-based bridge and sends a message specifying a wanted swap action on the 
               destination chain via the message bus
     * @param _receiver the app contract that implements the MessageReceiver abstract contract
     * @param _amountIn the input amount that the user wants to swap and/or bridge
     * @param _dstChainId destination chain ID
     * @param _srcSwap a struct containing swap related requirements
     * @param _dstSwap a struct containing swap related requirements
     * @param _maxBridgeSlippage the max acceptable slippage at bridge, given as percentage in point (pip). Eg. 5000 means 0.5%.
     *        Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least (100% - max slippage percentage) * amount or the
     *        transfer can be refunded.
     */
    function transferWithSwap(
        address _receiver,
        uint256 _amountIn,
        uint64 _dstChainId,
        SwapInfo calldata _srcSwap,
        SwapInfo calldata _dstSwap,
        uint32 _maxBridgeSlippage
    ) external onlyEOA {
        require(_srcSwap.path.length > 0, "empty src swap path");
        address srcTokenOut = _srcSwap.path[_srcSwap.path.length - 1];

        require(_amountIn > minSwapAmounts[_srcSwap.path[0]], "amount must be greateer than min swap amount");
        uint64 chainId = uint64(block.chainid);
        require(_srcSwap.path.length > 1 || _dstChainId != chainId, "noop is not allowed"); // revert early to save gas

        uint256 srcAmtOut = _amountIn;
        nonce += 1;

        // pull source token from user
        IERC20(_srcSwap.path[0]).safeTransferFrom(msg.sender, address(this), _amountIn);

        // swap source token for intermediate token on the source DEX
        bool ok = true;
        if (_srcSwap.path.length > 1) {
            (ok, srcAmtOut) = _trySwap(_srcSwap, address(this), _amountIn);
            if (!ok) revert("src swap failed");
        }

        bytes32 id; // id is only a means for history tracking
        if (_dstChainId == chainId) {
            // no need to bridge, directly send the tokens to user
            IERC20(srcTokenOut).safeTransfer(_receiver, srcAmtOut);
            // use uint64 for chainid to be consistent with other components in the system
            id = keccak256(abi.encode(msg.sender, chainId, _receiver, nonce, _srcSwap));
            emit DirectSwap(id, chainId, _amountIn, _srcSwap.path[0], srcAmtOut, srcTokenOut);
        } else {
            require(_dstSwap.path.length > 0, "empty dst swap path");
            require(srcTokenOut == _dstSwap.path[0], "srcSwap.path[len - 1] and dstSwap.path[0] must be the same");
            bytes memory message = abi.encode(SwapRequest({swap: _dstSwap, receiver: _receiver, nonce: nonce}));
            id = _computeSwapRequestId(msg.sender, chainId, _dstChainId, message);
            // bridge the intermediate token to destination chain along with the message
            sendMessageWithTransfer(_receiver, srcTokenOut, srcAmtOut, _dstChainId, nonce, _maxBridgeSlippage, message);
            emit SwapRequestSent(id, _dstChainId, srcAmtOut, _srcSwap.path[0], _dstSwap.path[_dstSwap.path.length - 1]);
        }
    }

    /**
     * @notice called by MessageBus when the tokens are checked to be arrived at this contract's address.
               sends the amount received to the receiver. swaps beforehand if swap behavior is defined in message
     * NOTE: if the swap fails, it sends the tokens received directly to the receiver as fallback behavior
     * @param _sender the address originator of the whole message passing process (the user)
     * @param _token the address of the token sent through the bridge
     * @param _amount the amount of tokens received at this contract through the cross-chain bridge
     * @param _srcChainId source chain ID
     * @param _message SwapRequest message that defines the swap behavior on this destination chain
     */
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessageBus {
        SwapRequest memory m = abi.decode((_message), (SwapRequest));
        require(_token == m.swap.path[0], "bridged token must be the same as the first token in destination swap path");
        bytes32 id = _computeSwapRequestId(_sender, _srcChainId, uint64(block.chainid), _message);
        uint256 dstAmount;
        SwapStatus status = SwapStatus.Succeeded;

        if (m.swap.path.length > 1) {
            bool ok = true;
            (ok, dstAmount) = _trySwap(m.swap, m.receiver, _amount);
            // handle swap failure, send the received token directly to receivr
            if (!ok) {
                IERC20(_token).safeTransfer(m.receiver, _amount);
                dstAmount = _amount;
                status = SwapStatus.Fallback;
            }
        } else {
            // no need to swap, directly send the bridged token to user
            IERC20(_token).safeTransfer(m.receiver, _amount);
            dstAmount = _amount;
            status = SwapStatus.Succeeded;
        }
        emit SwapRequestDone(id, dstAmount, status);
    }

    /**
     * @notice called by MessageBus when the executeMessageWithTransfer call fails. does nothing but emitting a "fail" event
     * @param _sender the address originator of the whole message passing process (the user)
     * @param _srcChainId source chain ID
     * @param _message SwapRequest message that defines the swap behavior on this destination chain
     */
    function executeMessageWithTransferFallback(
        address _sender,
        address, // _token
        uint256, // _amount
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessageBus {
        bytes32 id = _computeSwapRequestId(_sender, _srcChainId, uint64(block.chainid), _message);
        emit SwapRequestDone(id, 0, SwapStatus.Failed);
    }

    function _trySwap(
        SwapInfo memory _swap,
        address _receiver,
        uint256 _amount
    ) private returns (bool ok, uint256 amountOut) {
        uint256 zero;
        if (!supportedDex[_swap.dex]) {
            return (false, zero);
        }
        IERC20(_swap.path[0]).safeIncreaseAllowance(_swap.dex, _amount);
        try
            IUniswapV2(_swap.dex).swapExactTokensForTokens(
                _amount,
                _swap.minRecvAmt,
                _swap.path,
                _receiver,
                _swap.deadline
            )
        returns (uint256[] memory amounts) {
            return (true, amounts[amounts.length - 1]);
        } catch {
            return (false, zero);
        }
    }

    function _computeSwapRequestId(
        address _sender,
        uint64 _srcChainId,
        uint64 _dstChainId,
        bytes memory _message
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_sender, _srcChainId, _dstChainId, _message));
    }

    function setMinSwapAmount(address _token, uint256 _minSwapAmount) external onlyOwner {
        minSwapAmounts[_token] = _minSwapAmount;
    }

    function setSupportedDex(address _dex, bool _enabled) external onlyOwner {
        supportedDex[_dex] = _enabled;
    }
}
