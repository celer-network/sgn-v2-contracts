#!/bin/sh

# Script to run solt and generate standard-json files for Etherscan verification.

solFiles=(
  Bridge
  FarmingRewards
  Govern
  SGN
  Staking
  StakingReward
  Viewer
  WithdrawInbox
  integration-examples/ContractAsLP
  integration-examples/ContractAsSender
  interfaces/ISigsVerifier
  message/apps/TransferSwap
  message/messagebus/MessageBus
  miscs/Faucet
  miscs/MintableERC20
  pegged/OriginalTokenVault
  pegged/OriginalTokenVaultV2
  pegged/PeggedTokenBridge
  pegged/PeggedTokenBridgeV2
  pegged/tokens/ERC20Permit/MintSwapCanonicalTokenPermit
  pegged/tokens/ERC20Permit/MultiBridgeTokenPermit
  pegged/tokens/ERC20Permit/SingleBridgeTokenPermit
  pegged/tokens/MintSwapCanonicalToken
  pegged/tokens/MultiBridgeToken
  pegged/tokens/SingleBridgeToken
  pegged/tokens/SwapBridgeToken
  pegged/tokens/customized/FraxBridgeToken
  test-helpers/DummySwap
)

run_solt_write() {
  for f in ${solFiles[@]}; do
    solt write contracts/$f.sol --npm --runs 800
  done
}
