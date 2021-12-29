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

    uint64 SlippageDenominator = 1e6;
    uint64 nonce; // required by IBridge.send

    function transferWithSwap(
        address _receiver,
        uint256 _amountIn,
        uint64 _dstChainId,
        Swap calldata _srcSwap,
        Swap calldata _dstSwap,
        uint32 _maxBridgeSlippage
    ) external {
        address intermediaryToken = _srcSwap.path[_srcSwap.path.length - 1];
        require(_srcSwap.path.length > 0, "empty src swap path");
        require(_dstSwap.path.length > 0, "empty dst swap path");
        require(
            intermediaryToken == _dstSwap.path[0],
            "the last token in _srcSwapPath and the first token in dstPath must be the same"
        );

        nonce += 1;

        // pull source token from user
        IERC20(_srcSwap.path[0]).safeTransferFrom(msg.sender, address(this), _amountIn);

        // swap original token for intermediate token on the source DEX
        if (_srcSwap.path.length > 1) {
            IERC20(_srcSwap.path[0]).approve(_srcSwap.dex, _amountIn);
            IUniswapV2(_srcSwap.dex).swapExactTokensForTokens(
                _amountIn,
                _srcSwap.minRecvAmt,
                _srcSwap.path,
                address(this),
                _srcSwap.deadline
            );
        }

        // bridge the intermediate token to destination chain with message
        sendMessageWithTransfer(
            _receiver,
            intermediaryToken,
            IERC20(intermediaryToken).balanceOf(msg.sender),
            _dstChainId,
            nonce,
            _maxBridgeSlippage,
            abi.encode(_dstSwap)
        );
    }

    function executeMessageWithTransfer(
        address, // _sender
        address _token,
        uint256 _amount,
        uint64, // _srcChainId
        bytes memory _message
    ) external override onlyMessageBus {
        Swap memory m = abi.decode((_message), (Swap));
        require(_token == m.path[0], "bridged token must be the same as the first token in destination swap path");

        // swap intermediate token to the token user wants on the destination DEX
        if (m.path.length > 1) {
            IERC20(m.path[0]).approve(m.dex, _amount);
            IUniswapV2(m.dex).swapExactTokensForTokens(_amount, m.minRecvAmt, m.path, address(this), m.deadline);
        }
    }
}
