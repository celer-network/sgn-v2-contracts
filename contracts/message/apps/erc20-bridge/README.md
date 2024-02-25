# ERC20 Bridge using Celer IM
## Scope
- For one token like USDC, some chains are officially supported so bridge will use erc20 transfer (we call these vaults as tokens are locked in contract), others are mint/burn (called peg)
- If peg chain is later promoted to official (ie. becomes a vault chain), corresponding locked amount on vault chains must be burned to avoid duplicated supply (required by Circle)
- This bridge is only intended to work between vault and peg, or between peg and peg. For transfers between vault chains, use cBridge
- **ERC20 contract decimal MUST be the same among all chains** (we could add decimal into crosschain message with added cost and complexity)

## Fee
To ensure mint amount equals locked, fee is set and collected on dest chain. For example, user locks 100 on source chain, bridge will mint 100 on dest chain, and send 100-fee amount to receiver.

Fee has 2 parts:
- base fee: to cover gas cost for message executor. not related to source chain
- percentage fee: collected in bridge contract, may vary for different source chain due to business reason

## Contract
```solidity
/// MsgTokenBridge address on other chains, key is chain id
mapping(uint64 => address) public bridgeAddr;

/// for each erc20 token, config of cap, fee, etc. key is token address on this chain
mapping(address => tokenCfg) public tokenConfig;

struct tokenCfg {
    bool isVault; // default false, mint/burn. if set to true, use erc20 transfer for deposit/withdraw
    // send cap. set minSend to max will effectively stop new user requests
    uint256 minSend;
    uint256 maxSend;
    uint256 baseFee; // when emit token to receiver, cut baseFee to msg executor
    // fee percentage based on different source chain ids, key is source chain id, value is percentage * 1M, ie. 0.1% becomes 1000
    // 0 <= valid value <= 1M
    mapping(uint64 => uint32) feePerc;
    // token address on other chains, key is chain id
    mapping(uint64 => address) tokenAddr;
}
```
- Note: delay transfer and volume control parameters are set in their own contracts

## Refund
TBD