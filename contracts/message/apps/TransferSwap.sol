// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";
import "../../interfaces/IUniswapV2.sol";

contract TransferSwap is MsgSenderApp, MsgReceiverApp {
    using SafeERC20 for IERC20;

    struct Swap {
        address dex;
        address[] path;
        uint256 deadline;
        uint256 minRecvAmt;
    }

    struct SwapRequest {
        Swap swap;
        address receiver;
    }

    uint64 SlippageDenominator = 1e6;

    function transferWithSwap(
        address _receiver,
        uint256 _amountIn,
        uint64 _dstChainId,
        Swap calldata _srcSwap,
        Swap calldata _dstSwap,
        uint32 _maxBridgeSlippage,
        uint64 _nonce
    ) external {
        address bridgeToken = _srcSwap.path[_srcSwap.path.length - 1];
        uint256 bridgeTokenAmt = _amountIn;

        require(_srcSwap.path.length > 0, "empty src swap path");
        require(_dstSwap.path.length > 0, "empty dst swap path");
        require(
            bridgeToken == _dstSwap.path[0],
            "the last token in _srcSwapPath and the first token in dstPath must be the same"
        );

        // pull source token from user
        IERC20(_srcSwap.path[0]).safeTransferFrom(msg.sender, address(this), _amountIn);

        // swap original token for intermediate token on the source DEX
        if (_srcSwap.path.length > 1) {
            IERC20(_srcSwap.path[0]).approve(_srcSwap.dex, _amountIn);
            uint256[] memory amounts = IUniswapV2(_srcSwap.dex).swapExactTokensForTokens(
                _amountIn,
                _srcSwap.minRecvAmt,
                _srcSwap.path,
                address(this),
                _srcSwap.deadline
            );
            bridgeTokenAmt = amounts[amounts.length - 1];
        }

        // bridge the intermediate token to destination chain with message
        SwapRequest memory message = SwapRequest({swap: _dstSwap, receiver: _receiver});
        sendMessageWithTransfer(
            _receiver,
            bridgeToken,
            bridgeTokenAmt,
            _dstChainId,
            _nonce,
            _maxBridgeSlippage,
            abi.encode(message)
        );
    }

    function executeMessageWithTransfer(
        address, // _sender
        address _token,
        uint256 _amount,
        uint64, // _srcChainId
        bytes memory _message
    ) external override onlyMessageBus {
        SwapRequest memory m = abi.decode((_message), (SwapRequest));
        require(_token == m.swap.path[0], "bridged token must be the same as the first token in destination swap path");

        if (m.swap.path.length > 1) {
            // swap intermediate token to the token user wants on the destination DEX
            IERC20(m.swap.path[0]).approve(m.swap.dex, _amount);
            IUniswapV2(m.swap.dex).swapExactTokensForTokens(
                _amount,
                m.swap.minRecvAmt,
                m.swap.path,
                m.receiver,
                m.swap.deadline
            );
        } else {
            // no need to swap, directly send the bridged token to user
            IERC20(_token).transfer(m.receiver, _amount);
        }
    }
}
