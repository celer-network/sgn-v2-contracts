#!/bin/sh

# Script to run solt and generate standard-json files for Etherscan verification.

solFiles=(
  Bridge
  Staking
  SGN
  StakingReward
  FarmingRewards
  Govern
  Viewer
  WithdrawInbox
  interfaces/ISigsVerifier
  miscs/Faucet
  miscs/MintableERC20
  pegged/OriginalTokenVault
  pegged/PeggedTokenBridge
  pegged/tokens/customized/FraxBridgeToken
  pegged/tokens/ERC20Permit/MintSwapCanonicalTokenPermit
  pegged/tokens/ERC20Permit/MultiBridgeTokenPermit
  pegged/tokens/ERC20Permit/SingleBridgeTokenPermit
  pegged/tokens/MintSwapCanonicalToken
  pegged/tokens/MultiBridgeToken
  pegged/tokens/SingleBridgeToken
  pegged/tokens/SwapBridgeToken
  message/apps/TransferSwap
  test-helpers/DummySwap
  test-helpers/ContractAsLP
  message/messagebus/MessageBus
)

run_solt_write() {
  for f in ${solFiles[@]}; do
    solt write contracts/$f.sol --npm --runs 800
  done
}
