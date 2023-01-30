# A Brief Introduction for MultiBridge

Here we propose a solution for any developer who is for Vendor-Lock-in-Free implementation of cross-chain message passing and wants to build their business logic with cross-chain message without a single service provider, but a message governance based on utilizing services from multiple providers.

The framework to be introduced here is suitable for the scenario where messages are going to be sent from one source chain to multiple destination chain. Besides, it requires also there is only one sender on source chain. But there is no limit for the receiver on destination chain.

## Workflow

### Send message on source chain

In order to send message to destintion chain or technically speaking realize a remote call, sender on source chain should call `remoteCall()` of `MultiBridgeSender` with sufficient native token as message fee, as well as `_dstChainId`, `_target` and `_callData`. See [here](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/MultiBridgeSender.sol#L39-L41) for param doc. `_target` will be the real message receiver. A successful call would make `MultiBridgeSender` call `sendMessage()` of every available SenderAdapter to send message via different message bridge. Given a structured data which contains infos about caller's remote call, each SenderAdapter would encode it in their desire way and "sent" the result to their underlying infrastructure.

> Note. `MultiBridgeSender` contract maintains an array of available SenderAdapter.

> Note. A structured message looks like [this](https://github.com/celer-network/sgn-v2-contracts/blob/1cbc2a3038463e7569b1a459c3519c7fcfeaaa4a/contracts/message/apps/multibridge/MessageStruct.sol#L16). Messages sent via different SenderAdapters are same, except the `bridgeName` field which indicates the name of used message bridge.

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Source chain                                                                       │
│                                                                                    │
│                                                             ┌────────────────────┐ │  ┌──────────────────────┐
│                                                         ┌──►│ CelerSenderAdapter ├─┼─►│ Celer Infrastructure │
│                                                         │   └────────────────────┘ │  └──────────────────────┘
│                                                         │                          │
│ ┌────────┐remoteCall()┌───────────────────┐sendMessage()│   ┌────────────────────┐ │  ┌──────────────────────┐
│ │ Caller ├───────────►│ MultiBridgeSender ├─────────────┼──►│ D****SenderAdapter ├─┼─►│ D**** Infrastructure │
│ └────────┘            └───────────────────┘             │   └────────────────────┘ │  └──────────────────────┘
│                                                         │                          │
│                                                         │   ┌────────────────────┐ │  ┌──────────────────────┐
│                                                         └──►│ E****SenderAdapter ├─┼─►│ E**** Infrastructure │
│                                                             └────────────────────┘ │  └──────────────────────┘
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### Receive message on destination chain

Corresponding to the fact that `MultiBridgeSender` sends message to every SenderAdapter on source chain, on destination chain, MultiBridgeReceiver will receive messages from every ReceiverAdapter. This receiving process happens when each ReceiverAdapter get encoded message data from their message bridge infrastructure. After necessary security check, each ReceiverAdapter would decode message and call `receiveMessage()` of MultiBrideReceiver.

> Note. Similar to `MultiBridgeSender`, `MultiBridgeReceiver` maintain a map from ReceiverAdapter address to its power. Only adapter with non-zero power has access to `receiveMessage()` function.

Within `MultiBridgeReceiver`, a message governance get involved. In current implementation, an adjustable power threshold is introduced to realize a simple n-of-m governance model. Every ReceiverAdapter has its own power value stored in `MultiBridgeReceiver`.

> Note. By hashing all fields except `bridgeName`, we get a unique id for each set of related messages, which are sent in same tx on source chain but via different senders.

Every time a message get received, we calculate the unique id, get current accumulated power by this id and augment it by the power of the ReceiverAdapter where this message come from. Once the accumulated power reach or exceed the power threshold after augmentation, this message will be executed immediately. In another word, a solidity low-level call to receiver(or target) would be triggerred.

For the receiver(or target), there are two possibilities, which are:

- any other contract on destination chain for whatever purpose.
- `MultiBridgeReceiver` itself for sake of updating ReceiverAdapters' power or adjust power threshold.

```
                          ┌──────────────────────────────────────────────────────────────────────────────────────────┐
                          │ Destination chain                                                                        │
                          │                                                                                          │
┌──────────────────────┐  │  ┌──────────────────────┐                                                                │
│ Celer Infrastructure ├──┼─►│ CelerReceiverAdapter ├──┐                                                             │
└──────────────────────┘  │  └──────────────────────┘  │                                       solidity              │
                          │                            │                                       low-level             │
┌──────────────────────┐  │  ┌──────────────────────┐  │receiveMessage()┌─────────────────────┐call     ┌──────────┐ │
│ D**** Infrastructure ├──┼─►│ D****ReceiverAdapter ├──┼───────────────►│ MultiBridgeReceiver ├────────►│ Receiver │ │
└──────────────────────┘  │  └──────────────────────┘  │                └─────────────────────┘         └──────────┘ │
                          │                            │      * Message governance get invovled   * Receiver could be│
┌──────────────────────┐  │  ┌──────────────────────┐  │      in MultiBridgeReceiver during       MultiBridgeReceiver│
│ E**** Infrastructure ├──┼─►│ E****ReceiverAdapter ├──┘      receiving messages from adapters                       │
└──────────────────────┘  │  └──────────────────────┘         before making a low-level call                         │
                          │                                                                                          │
                          └──────────────────────────────────────────────────────────────────────────────────────────┘
```

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
