# Send Cross-Chain Messages through Multiple Bridges

This is a solution for cross-chain message passing without vendor lock-in and with enhanced security beyond any single bridge.
A message with multiple copies are sent through different bridges to the destination chains, and will only be executed at the destination chain when the same message has been delivered by a quorum of different bridges.

The current solution are designed for messages being sent from one source chain to multiple destination chains. It also requires that there is only one permitted sender on the source chain. For example, one use case could be a governance contract on Ethereum
calling remote functions of contracts on other EVM chains. Each dApp who wants to utilize this framework needs to deploy its own set of contracts.

## Workflow

### Send message on source chain

To send a message to execute a remote call on the destintion chain, sender on the source chain should call [`remoteCall()`](https://github.com/celer-network/sgn-v2-contracts/blob/261fe55b320393a1336156b5771867a36db43198/contracts/message/apps/multibridge/MultiBridgeSender.sol#L28-L40) of `MultiBridgeSender`, which invokes `sendMessage()` of every bridge sender apdater to send messages via different message bridges.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Source chain                                                                                            │
│                                                                                                         │
│                                                             ┌─────────────────┐   ┌───────────────────┐ │
│                                                         ┌──►│ Bridge1 Adapter ├──►│ Bridge1 Contracts │ │
│                                                         │   └─────────────────┘   └───────────────────┘ │
│                                                         │                                               │
│ ┌────────┐remoteCall()┌───────────────────┐sendMessage()│   ┌─────────────────┐   ┌───────────────────┐ │
│ │ Caller ├───────────►│ MultiBridgeSender ├─────────────┼──►│ Bridge2 Adapter ├──►│ Bridge2 Contracts │ │
│ └────────┘            └───────────────────┘             │   └─────────────────┘   └───────────────────┘ │
│                                                         │                                               │
│                                                         │   ┌─────────────────┐   ┌───────────────────┐ │
│                                                         └──►│ Bridge3 Adapter ├──►│ Bridge3 Contracts │ │
│                                                             └─────────────────┘   └───────────────────┘ │
│                                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Receive message on destination chain

On the destination chain, MultiBridgeReceiver receives messages from every bridge receiver adapter. Each receiver adapter gets encoded message data from its bridge contracts, and then decode the message and call `receiveMessage()` of `MultiBrideReceiver`.

`MultiBridgeReceiver` maintains a map from bridge adapter address to its power. Only adapter with non-zero power has access to `receiveMessage()` function. **If the accumulated power of a message has reached the a threshold, which means enough number of different bridges have delivered a same message, the message will be executed** by the `MultiBrideReceiver` contract.

The message execution will invoke a function call according to the message content, which will either call functions of other contracts, or call the param adjustment functions of the `MultiBridgeReceiver` itself. Note that the only legit message sender is the trusted dApp contract on the source chain, which means only that single dApp contract has the ability to execute functions calls through the `MultiBridgeReceiver` contracts on different other chains.

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Destination chain                                                                                          │
│                                                                                                            │
│ ┌───────────────────┐   ┌─────────────────┐                                                                │
│ │ Bridge1 Contracts ├──►│ Bridge1 Adapter ├──┐                                                             │
│ └───────────────────┘   └─────────────────┘  │                                                             │
│                                              │                                                             │
│ ┌───────────────────┐   ┌─────────────────┐  │receiveMessage()┌─────────────────────┐ call()  ┌──────────┐ │
│ │ Bridge1 Contracts ├──►│ Bridge2 Adapter ├──┼───────────────►│ MultiBridgeReceiver ├────────►│ Receiver │ │
│ └───────────────────┘   └─────────────────┘  │                └─────────────────────┘         └──────────┘ │
│                                              │                                                             │
│ ┌───────────────────┐   ┌─────────────────┐  │                                                             │
│ │ Bridge2 Contracts ├──►│ Bridge3 Adapter ├──┘                                                             │
│ └───────────────────┘   └─────────────────┘                                                                │
│                                                                                                            │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### add new bridge and update threshold

If a new bridge (e.g. Bridge4) needs to be added in this framework, following steps are recommended to do it:

* Pre-requisite: 

## Example

Use case: contract A on Goerli send message to contract B on BSC Testnet in order to call `enableFeeAmount()` for state change. Apply a 2-of-3 messages governance model with message bridge C, D and E.

### Deployment and initialization

- Deploy `MultiBridgeSender` on Goerli, set address of A as allowed [caller](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/MultiBridgeSender.sol#L12).
- Deploy `MultiBridgeReceiver` on BSC Testnet.
- Each message bridge provider prepare their own `SenderAdapter` and `ReceiverAdapter`, named with a prefix of their bridge name. Take preparation of `CSenderAdapter` and `CReceiverAdapter` as an example.
  - Deploy `CSenderAdapter` on Goerli, set address of `MultiBridgeSender` as [multiBridgeSender](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/adapters/CelerSenderAdapter.sol#L12).
  - Deploy `CReceiverAdapter` on BSC Testnet, set address of `MultiBridgeReceiver` as [multiBridgeReceiver](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/adapters/CelerReceiverAdapter.sol#L34).
  - Call [updateReceiverAdapter()](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/adapters/CelerSenderAdapter.sol#L42) of `CSenderAdapter`, set address of `CReceiverAdapter` on BSC Testnet(chain id 97) as a valid ReceiverAdapter.
  - Call [updateSenderAdapter()](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/adapters/CelerReceiverAdapter.sol#L60) of `CReceiverAdapter`, set address of `CSenderAdapter` on Goerli(chain id 5) as a valid SenderAdapter.
  - Transfer ownership of `CSenderAdapter` and `CReceiverAdapter` to address(0).
- Once all message bridges are ready, somehow let contract A call [addSenderAdapters()](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/MultiBridgeSender.sol#L74) of `MultiBridgeSender` with an address array of `CSenderAdapter`, `DSenderAdapter` and `ESenderAdapter`.
- Call `initialize()` of `MultiBridgeReceiver`, with an address array of `CReceiverAdapter`, `DReceiverAdapter` and `EReceiverAdapter`, and power threshold 2.

### Sending your message

Prepare a calldata for contract B for calling `enableFeeAmount()`, then somehow let contract A call `remoteCall()` of `MultiBridgeSender` with `_dstChainId = 97`, `_target = <address of contract B>` and `_callData = <calldata you prepared>`.

### Result

Imagine that the messages sent via C, D and E received by `MultiBridgeReceiver` on BSC Testnet in an order of `1.C 2.D 3.E`. During receiving message sent via D, accumulated power reaches power threshold 2, which result in message execution(the calldata will be sent to contract B).
