// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";
import "../../interfaces/IUniswapV2.sol";

contract TransferSwap is MsgSenderApp, MsgReceiverApp {
    using SafeERC20 for IERC20;

    struct Swap {
        // single element in this array means no need to swap
        address[] path;
        // only needed if path.length > 1
        address dex;
        uint256 deadline;
        uint256 minRecvAmt;
    }

    struct SwapRequest {
        address dex;
        address[] path;
        uint256 deadline;
        uint256 minRecvAmt;
        address receiver;
        uint64 nonce;
    }

    event SwapRequestSent(bytes32 id, uint64 dstChainId, uint256 srcAmount, address srcToken, address dstToken);
    event SwapRequestDone(bytes32 id, uint256 dstAmount);

    mapping(address => uint256) minSwapAmounts;
    uint64 nonce;

    function transferWithSwap(
        address _receiver,
        uint256 _amountIn,
        uint64 _dstChainId,
        Swap calldata _srcSwap,
        Swap calldata _dstSwap,
        uint32 _maxBridgeSlippage
    ) external {
        require(_srcSwap.path.length > 0, "empty src swap path");
        require(_dstSwap.path.length > 0, "empty dst swap path");

        address bridgeToken = _srcSwap.path[_srcSwap.path.length - 1];
        require(bridgeToken == _dstSwap.path[0], "srcSwap.path[len - 1] and dstSwap.path[0] must be the same");
        require(_amountIn > minSwapAmounts[_srcSwap.path[0]], "amount has to be greateer than min swap amount");

        nonce += 1;

        uint256 bridgeTokenAmt = _amountIn;

        // pull source token from user
        IERC20(_srcSwap.path[0]).safeTransferFrom(msg.sender, address(this), _amountIn);

        // swap source token for intermediate token on the source DEX
        if (_srcSwap.path.length > 1) {
            IERC20(_srcSwap.path[0]).safeIncreaseAllowance(_srcSwap.dex, _amountIn);
            uint256[] memory amounts = IUniswapV2(_srcSwap.dex).swapExactTokensForTokens(
                _amountIn,
                _srcSwap.minRecvAmt,
                _srcSwap.path,
                address(this),
                _srcSwap.deadline
            );
            bridgeTokenAmt = amounts[amounts.length - 1];
        }

        // bridge the intermediate token to destination chain along with the message
        bytes memory message = abi.encode(
            SwapRequest({
                dex: _dstSwap.dex,
                path: _dstSwap.path,
                deadline: _dstSwap.deadline,
                minRecvAmt: _dstSwap.minRecvAmt,
                receiver: _receiver,
                nonce: nonce
            })
        );
        sendMessageWithTransfer(
            _receiver,
            bridgeToken,
            bridgeTokenAmt,
            _dstChainId,
            nonce,
            _maxBridgeSlippage,
            message
        );

        // compute id & emit event for gateway to track history
        // use uint64 for chainid to be consistent with other components in the system
        bytes32 id = keccak256(abi.encodePacked(msg.sender, uint64(block.chainid), _dstChainId, message));
        emit SwapRequestSent(
            id,
            _dstChainId,
            bridgeTokenAmt,
            _srcSwap.path[0],
            _dstSwap.path[_dstSwap.path.length - 1]
        );
    }

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external override onlyMessageBus {
        SwapRequest memory m = abi.decode((_message), (SwapRequest));
        require(_token == m.path[0], "bridged token must be the same as the first token in destination swap path");

        uint256 dstAmount;
        if (m.path.length > 1) {
            IERC20(m.path[0]).safeIncreaseAllowance(m.dex, _amount);
            uint256[] memory amounts = IUniswapV2(m.dex).swapExactTokensForTokens(
                _amount,
                m.minRecvAmt,
                m.path,
                m.receiver,
                m.deadline
            );
            dstAmount = amounts[amounts.length - 1];
        } else {
            // no need to swap, directly send the bridged token to user
            IERC20(_token).safeTransfer(m.receiver, _amount);
            dstAmount = _amount;
        }
        bytes32 id = keccak256(abi.encodePacked(_sender, _srcChainId, uint64(block.chainid), _message));
        emit SwapRequestDone(id, dstAmount);
    }

    function setMinSwapAmount(address token, uint256 _minSwapAmount) external onlyOwner {
        minSwapAmounts[token] = _minSwapAmount;
    }
}
