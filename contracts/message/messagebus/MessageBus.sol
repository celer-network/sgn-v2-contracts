// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./MessageSender.sol";
import "./MessageReceiver.sol";

contract MessageBus is MessageSender, MessageReceiver {}
