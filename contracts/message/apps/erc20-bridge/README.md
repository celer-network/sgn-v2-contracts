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
### Overview
Similar to NFT bridge, one bridge contract handles both vault and peg. This is mainly due to we have to save bridge addresses on other chains, one unified contract simplifies logic and saves storage cost.
- since contract knows if token is vault or peg, we only need one function for user like `sendTo`, but if frontend prefers compatibility with existing cBridge pegbridge ABIs, we can support deposit and burn by simple wrapper, note the only difference from cBridge is that these calls are `payable` as user must pay Celer IM msg bus for message fee in source chain gas token.

### Key configurations
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
Cases emit token to user may fail:
- Can’t mint(role revoked, cap reached etc). retryable
- Amount less than baseFee due to incorrect minSend on source chain. retryable
- transfer failed due to receiver address is restricted by token contract. non-retryable
- vault chain has no enough locked token, this could happen when 2 vault chains exist for same token. retryable but no guarantee

Decision is to require manual trigger for refund on dest chain of failed transfer. A refund message will be sent to source chain where user locked/burn tokens.
