#!/bin/sh

# Script to run solt and generate standard-json files for Etherscan verification.

solFiles=(
  governed-owner/GovernedOwnerProxy
  governed-owner/SimpleGovernance
  integration-examples/ContractAsLP
  integration-examples/ContractAsSender
  interfaces/ISigsVerifier
  liquidity-bridge/Bridge
  liquidity-bridge/FarmingRewards
  liquidity-bridge/WithdrawInbox
  message/apps/TransferSwap
  message/apps/OrigNFT
  message/apps/PegNFT
  message/apps/MCNNFT
  message/apps/NFTBridge
  message/apps/MsgTest
  message/apps/RFQ
  message/apps/adapter/MessageReceiverAdapter
  message/messagebus/MessageBus
  miscs/Faucet
  miscs/MintableERC20
  pegged-bridge/OriginalTokenVault
  pegged-bridge/OriginalTokenVaultV2
  pegged-bridge/PeggedTokenBridge
  pegged-bridge/PeggedTokenBridgeV2
  pegged-bridge/tokens/ERC20Permit/MintSwapCanonicalTokenPermit
  pegged-bridge/tokens/ERC20Permit/MultiBridgeTokenPermit
  pegged-bridge/tokens/ERC20Permit/SingleBridgeTokenPermit
  pegged-bridge/tokens/MintSwapCanonicalToken
  pegged-bridge/tokens/MultiBridgeToken
  pegged-bridge/tokens/SingleBridgeToken
  pegged-bridge/tokens/SwapBridgeToken
  pegged-bridge/tokens/customized/FraxBridgeToken
  pegged-bridge/tokens/owners/RestrictedMultiBridgeTokenOwner
  proxy/TransferAgent
  staking/Govern
  staking/SGN
  staking/Staking
  staking/StakingReward
  staking/Viewer
  test-helpers/DummySwap
  test-helpers/WETH
  message/apps/multibridge/adapters/WormholeSenderAdapter
  message/apps/multibridge/adapters/WormholeReceiverAdapter
  message/apps/multibridge/adapters/CelerSenderAdapter
  message/apps/multibridge/adapters/CelerReceiverAdapter
  message/apps/multibridge/MultiBridgeSender
  message/apps/multibridge/MultiBridgeReceiver
  message/apps/multibridge/mock/MockCaller
)

run_solt_write() {
  for f in ${solFiles[@]}; do
    solt write contracts/$f.sol --npm --runs 800
  done
}
