# cBridge General Message Passing [WIP]

**Note: cBridge general message passing module is work in progress, and is subject to change in later iterations**

- [End-to-End Flow](#end-to-end-flow)
- [Application Framework](#application-framework)
- [Fee Mechanims](#fee-mechanism)

## End-to-End Flow

### Cross-chain message passing with token transfer

SrcApp at source chain wants to send some tokens to DstApp at destination chain, along with an arbitrary message associated with the transfer. Figure below describes the end-to-end flow of such transfers. The SrcApp sends both cross-chain token transfer and message passing requests in the same transaction. SGN catches and correlates both events, then completes the token transfer at the destination chain. The executor then submits the SGN-signed message and token transfer info to the message bus at the destination chain, which will verify the submitted info and call DstApp to execute the message.

![MsgTransfer](pics/msg-transfer-flow.png 'Figure 1: Cross-chain message passing with token transfer')

### Cross-chain message passing only

SrcApp at source chain wants to send an arbitrary message to DstApp at destination chain without associated token transfer. Figure below describes the end-to-end flow, which is a subset of the above flow.

![Msg](pics/msg-only-flow.png 'Figure 1: Cross-chain message passing without token transfer')

## Application Framework

We provide the [message bus contract](./messagebus) and [application framework](./framework), which implement the common process of message passing, including sending, receiving, and validating messages and token transfers. After inherent the app framework contracts, **the app developers only need to focus on the app-specific logic.**

- To send cross-chain message and token transfer, the app needs to inherent [MsgSenderApp.sol](./framework/MessageSenderApp.sol) and call the utils functions.
- To receive cross-chain message and token transfer, the app needs to inherent [MsgReceiverApp.sol](./framework/MessageReceiverApp.sol) and implement its virtual functions.

### Example 1: [Batch Token Transfer](./apps/BatchTransfer.sol)

[BatchTransfer.sol](./apps/BatchTransfer.sol) is an example app that sends tokens from one sender at the source chain to multiple receivers at the destination chain through a single cross-chain token transfer. The high-level workflow consists of three steps:

1. Sender side calls `batchTransfer` at source chain, which internally calls app framework's `sendMessageWithTransfer` to send message and tokens.
2. Receiver side implements the `executeMessageWithTransfer` interface to handle the batch transfer message, and distribute tokens to receiver accounts according to the message content. It also internally calls app framework's `sendMessage` to send a receipt to the source app.
3. Sender side implements the `executeMessage` interface to handle the receipt message.

### Example 2: [Cross Chain Swap](./apps/TransferSwap.sol)

[TransferSwap.sol](./apps/TransferSwap.sol) is an example app that allows swapping one token on chain1 to another token on chain2 through cBridge and DEXes on both chain1 and chain2.

For the simplicity of explanation, let's say we deploy this contract on chain1 and chain2, and we want to input tokenA on chain1 and gain tokenC on chain2.

Public functions `transferWithSwap` and `transferWithSwapNative` are called by a user to initiate the entire process. These functions takes in a `SwapInfo` struct that specifies the behavior or "route" of the execution, and execute the process in the following fashion:

1. Swap tokenA on the source chain to gain tokenB
2. Packages a `SwapRequest` as a "message", which indicates the swap behavior on chain2
3. `sendMessageWithTransfer` is then called internally to send the message along with the tokenB through the bridge to chain2
4. On chain2, `executeMessageWithTransfer` is automatically called when the bridge determines that the execution conditions are met.
5. This contract parses the message received to a `SwapRequest` struct, then executes the swap using the tokenB received to gain tokenC. (Note: when `executeMessageWithTransfer` is called, it is guaranteed that tokenB is already arrived at the TransferSwap contract address on chain2. You can check out this part of verification logic in [MessageBusReceiver.sol](./messagebus/MessageBusReceiver.sol)'s `executeMessageWithTransfer`).
6. If the execution of `executeMessageWithTransfer` of TransferSwap contract on chain2 reverts, or if the `executeMessageWithTransfer` call returns `false`, then MessageBus would call `executeMessageWithTransferFallback`. This is the place where you implement logic to decide what to do with the received tokenB.

The following is a more graphical explanation of all the supported flows of this demo app:

```
1. swap bridge swap

|--------chain1--------|-----SGN-----|---------chain2--------|
tokenA -> swap -> tokenB -> bridge -> tokenB -> swap -> tokenC -> out

2. swap bridge

|--------chain1--------|-----SGN-----|---------chain2--------|
tokenA -> swap -> tokenB -> bridge -> tokenB -> out

3. bridge swap

|--------chain1--------|-----SGN-----|---------chain2--------|
                  tokenA -> bridge -> tokenA -> swap -> tokenB -> out

4. just swap

|--------chain1--------|
tokenA -> swap -> tokenB -> out
```

### CAVEAT

Since bridging tokens requires a nonce to deduplicate same-parameter transactions, it is important that `sendMessageWithTransfer` is called with a nonce that is unique for every transaction at a per-contract per-chain level, meaning your application should always call `transferWithSwap` with a different nonce every time. Duplicated nonce can result in duplicated transferids. Checkout how a transferId is computed [here](https://github.com/celer-network/sgn-v2-contracts/blob/c5583b9c6db54a85e4e2254d2d73aba5a9e909fa/contracts/Bridge.sol#L48).

### Example 3: [Refund](./apps/TestRefund.sol)

[TestRefund.sol](./apps/TestRefund.sol) was originally written for testing, but it also demostrates how you can handle a refund in case of bridging failures (bad slippage, non-existant token, amount too smol, etc...)

The function `executeMessageWithTransferRefund` will be called by your executor automatically on the source chain when it finds out that there is any available refund for your contract in SGN. Like in `executeMessageWithTransfer`, you can expect that the tokens are guaranteed to arrive at the contract before the function is called. The `_message` you receive in this function is exactly the same as it was sent through `sendMessageWithTransfer`.

## Fee Mechanism

### SGN Fee

SGN charges fees to sync, store, and sign messages. Whoever calls `sendMessageWithTransfer` or `sendMessage` in [MessageBusSender](./messagebus/MessageBusSender.sol) should put some fee as `msg.value` in the transaction, which will later be distributed to SGN validators and delegators. The fee amount is calculated as `feeBase + _message.length * feePerByte`.

### Executor Fee

Executor charges fees to submit executeMessage transactions. How to charge and distribute executor fees is entirely decided at the application level. Celer IM framework does not enforce any executor fee mechanism.
