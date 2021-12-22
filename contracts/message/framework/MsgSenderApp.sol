// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBridge.sol";
import "./Addrs.sol";
import "../messagebus/MessageBus.sol";

abstract contract MsgSenderApp is Addrs {
    using SafeERC20 for IERC20;

    // ============== functions called by apps ==============

    function sendMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message
    ) internal {
        MessageBus(msgBus).sendMessage(_receiver, _dstChainId, _message);
    }

    function sendMessageWithTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        bytes memory _message
    ) internal {
        IERC20(_token).safeIncreaseAllowance(liquidityBridge, _amount);
        IBridge(liquidityBridge).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
        bytes32 transferId = keccak256(
            abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
        );
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, liquidityBridge, transferId, _message);
    }

    function sendMessageWithPegDeposit(
        address _receiver, // mintAccount
        address _token,
        uint256 _amount,
        uint64 _dstChainId, // mintChainId
        uint64 _nonce,
        bytes memory _message
    ) internal {
        IBridge(pegVault).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
        bytes32 depositId = keccak256(
            abi.encodePacked(address(this), _token, _amount, _dstChainId, _receiver, _nonce, uint64(block.chainid))
        );
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, pegVault, depositId, _message);
    }

    function sendMessageWithPegBurn(
        address _receiver, // withdrawAccount
        address _token,
        uint256 _amount,
        uint64 _dstChainId, // withdrawChainId
        uint64 _nonce,
        bytes memory _message
    ) internal {
        IBridge(pegBridge).burn(_token, _amount, _receiver, _nonce);
        bytes32 burnId = keccak256(
            abi.encodePacked(address(this), _token, _amount, _receiver, _nonce, uint64(block.chainid))
        );
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, pegBridge, burnId, _message);
    }
}
