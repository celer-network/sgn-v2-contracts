// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBridge.sol";
import "./MsgBusAddr.sol";
import "../messagebus/MessageBus.sol";

abstract contract MsgSenderApp is MsgBusAddr {
    using SafeERC20 for IERC20;

    address public liquidityBridge; // liquidity bridge address
    address public pegBridge; // peg bridge address
    address public pegVault; // peg original vault address

    enum BridgeType {
        Null,
        Liquidity,
        PegDeposit,
        PegBurn
    }
    mapping(address => BridgeType) public tokenBridgeTypes;

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
        BridgeType bt = tokenBridgeTypes[_token];
        address bridge;
        bytes32 transferId;
        if (bt == BridgeType.Liquidity) {
            bridge = liquidityBridge;
            IERC20(_token).safeIncreaseAllowance(liquidityBridge, _amount);
            IBridge(liquidityBridge).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
            transferId = keccak256(
                abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
            );
        } else if (bt == BridgeType.PegDeposit) {
            bridge = pegVault;
            IBridge(pegVault).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _dstChainId, _receiver, _nonce, uint64(block.chainid))
            );
        } else if (bt == BridgeType.PegBurn) {
            bridge = pegBridge;
            IBridge(pegBridge).burn(_token, _amount, _receiver, _nonce);
            transferId = keccak256(
                abi.encodePacked(address(this), _token, _amount, _receiver, _nonce, uint64(block.chainid))
            );
        } else {
            revert("bridge token not supported");
        }
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, bridge, transferId, _message);
    }

    function sendTokenTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) internal {
        BridgeType bt = tokenBridgeTypes[_token];
        if (bt == BridgeType.Liquidity) {
            IERC20(_token).safeIncreaseAllowance(liquidityBridge, _amount);
            IBridge(liquidityBridge).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
        } else if (bt == BridgeType.PegDeposit) {
            IBridge(pegVault).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
        } else if (bt == BridgeType.PegBurn) {
            IBridge(pegBridge).burn(_token, _amount, _receiver, _nonce);
        } else {
            revert("bridge token not supported");
        }
    }

    function setLiquidityBridge(address _addr) public onlyOwner {
        liquidityBridge = _addr;
    }

    function setPegBridge(address _addr) public onlyOwner {
        pegBridge = _addr;
    }

    function setPegVault(address _addr) public onlyOwner {
        pegVault = _addr;
    }

    function setTokenBridgeType(address _token, BridgeType bt) public onlyOwner {
        tokenBridgeTypes[_token] = bt;
    }
}
