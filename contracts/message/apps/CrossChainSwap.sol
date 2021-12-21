// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >= 0.8.9;

import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";

interface ISwapToken {
    function sellBase(address to) external returns (uint256);
    /* function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external returns (uint[]);
    */
}

contract CrossChainSwap is MsgSenderApp, MsgReceiverApp {
    using SafeERC20 for IERC20;

    address public dex; // needed on swap chain

    struct SwapInfo {
        address wantToken; // token user want to receive on dest chain
        address user;
        bool sendBack; // if true, send wantToken back to start chain
        uint32 cbrMaxSlippage; // _maxSlippage for cbridge send
    }

    constructor(address dex_) {
        dex = dex_;
    }
    // ========== on start chain ==========

    uint64 nonce; // required by IBridge.send

    // this func could be called by a router contract
    function startCrossChainSwap(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        SwapInfo swapInfo // wantToken on destChain and actual user address as receiver when send back
    ) external {
        nonce += 1;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = abi.encode(swapInfo);
        sendMessageWithTransfer(_receiver, _token, _amount, _dstChainId, nonce, swapInfo.cbrMaxSlippage, message);
    }

    // handleMessage?


    // ========== on swap chain ==========
    uint64 nonce2; // if need to send back
    // do dex, send received asset to src chain via bridge
    function handleMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal override {
        SwapInfo memory swapInfo = abi.decode((_message), (SwapInfo));
        uint256 received = ISwapToken(dex).sellBase(swapInfo.wantToken);
        if (swapInfo.sendBack) {
            nonce2 += 1;
            // send received token back to start chain
            IBridge(liquidityBridge).send(swapInfo.user, swapInfo.wantToken, received, _srcChainId, nonce2, swapInfo.cbrMaxSlippage);
        } else {
            IERC20(swapInfo.wantToken).safeTransfer(swapInfo.user, received);
        }
        // bytes memory notice; // send back to src chain to handleMessage
        // sendMessage(_sender, _srcChainId, notice);
    }
}