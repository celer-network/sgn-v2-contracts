// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./MsgBusAddr.sol";

abstract contract MsgReceiverApp is MsgBusAddr {
    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    /**
     * @notice called by MessageBus (MessageReceiver) if the process is originated from MessageBus (MessageSender)'s 
     *         sendMessageWithTransfer it is only called when the tokens are checked to be arrived at this contract's address.
     * @param _sender the address of the source app contract
     * @param _token the address of the token that comes out of the bridge
     * @param _amount the amount of tokens received at this contract through the cross-chain bridge. 
              the contract that implements this contract can safely assume that the tokens will arrive before this
              function is called.
     * @param _srcChainId the source chain ID where the transfer is originated from
     * @param _message arbitrary message bytes originated from and encoded by the source app contract
     */
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus returns (bool) {}

    /**
     * @notice only called by MessageBus (MessageReceiver) if
               1. executeMessageWithTransfer reverts, or
               2. executeMessageWithTransfer returns false
               the params are the same as executeMessageWithTransfer
     */
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus returns (bool) {}

    /**
     * @notice called by MessageBus (MessageReceiver) to process refund of the original transfer from this contract
     * @param _token the token address of the original transfer
     * @param _amount the amount of the original transfer
     * @param _message the same message associated with the original transfer
     */
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message
    ) external virtual onlyMessageBus returns (bool) {}

    /**
     * @notice called by MessageBus (MessageReceiver)
     * @param _sender the address of the source app contract
     * @param _srcChainId the source chain ID where the transfer is originated from
     * @param _message arbitrary message bytes originated from and encoded by the source app contract
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus returns (bool) {}
}
