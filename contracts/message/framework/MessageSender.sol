// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBridge.sol";
import "./Addrs.sol";
import "../MessageBus.sol";

abstract contract MessageSender is Addrs {
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
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce,
        bytes memory _message
    ) internal {
        IBridge(pegVault).deposit(_token, _amount, _mintChainId, _mintAccount, _nonce);
        bytes32 depositId = keccak256(
            abi.encodePacked(address(this), _token, _amount, _mintChainId, _mintAccount, _nonce, uint64(block.chainid))
        );
        MessageBus(msgBus).sendMessageWithTransfer(_mintAccount, _mintChainId, pegVault, depositId, _message);
    }

    function sendMessageWithPegBurn(
        address _token,
        uint256 _amount,
        uint64 _withdrawChainId,
        address _withdrawAccount,
        uint64 _nonce,
        bytes memory _message
    ) internal {
        IBridge(pegBridge).burn(_token, _amount, _withdrawAccount, _nonce);
        bytes32 burnId = keccak256(
            abi.encodePacked(address(this), _token, _amount, _withdrawAccount, _nonce, uint64(block.chainid))
        );
        MessageBus(msgBus).sendMessageWithTransfer(_withdrawAccount, _withdrawChainId, pegVault, burnId, _message);
    }
}
