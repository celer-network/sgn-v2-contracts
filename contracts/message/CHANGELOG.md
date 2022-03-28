# 03/28/2022 Message Bridge Upgrade Notes

## MsgDataTypes

- Most message bridge related data types are now in a separate library `MsgDataTypes`. Some types have there naming changed but no structual change.

- `MsgDataTypes.BridgeSendType` (originally `BridgeType`) now has three more types `PegV2Deposit`, `PegV2Burn`, and `PegV2BurnFrom`.

## MessageReceiverApp

- Receiver functions `executeMessageWithTransfer`, `executeMessageWithTransferFallback`, `executeMessageWithTransferRefund`, `executeMessage` now has an extra param `address _executor` that the app dveloper could use to check who submitted the execution.

- Receiver functions' required return value also changed from a `boolean` "success" to `IMessageBusReceiver.ExecutionStatus` to accomodate a third state `ExecutionStatus.Retry`. This status indicates that the message processing should not be regarded as "processed" by MessageBus and is simply ignored. This status can be used in conjunction with the above mentioned `address _executor` to completely ignore executions that are not originated from a specific executor.

## MessageBus (MessageBusReceiver)

- Added a helper function `refund()` to aggregate refund call to `Bridge.withdraw()` and `MessageBus.executeMessageWithTransferRefund()` into one call.

- Added a new event `NeedRetry`, emitted when the execution is indicated as `MsgDataTypes.ExecutionStatus.Retry`.

- Added a field `srcTxHash` in `Executed` and `NeedRetry` event to enable third parties to co-verify a whether a tx does happen on the source chain (in the name of not completely trusting message bus).
