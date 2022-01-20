// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

contract WithdrawInbox {

    // contract LP withdrawal request
    event WithdrawalRequest (
        address sender,
        address receiver,
        uint64 toChain,
        uint64[] fromChains,
        address[] tokens,
        uint32[] ratios,
        uint32[] slippages
    );

    /**
     * @notice Withdraw liquidity from the pool-based bridge.
     * NOTE: ONLY call this from a contract address. DO NOT call from an EOA.
     * NOTE: _fromChains, _tokens, _ratios, _slippages should have the same length.
     * @param _receiver The receiver address on _toChain.
     * @param _toChain The chainId of chain to which withdrew tokens would be transferred.
     * @param _fromChains THe chainId of chains from which withdrew tokens would be transferred.
     * @param _tokens The tokens to be withdrew.
     * @param _ratios The withdrawal ratios of each token.
     * @param _slippages The max slippages of each token for cross-chain transfer.
     */
    function withdraw(
        address calldata _receiver,
        uint64 calldata _toChain,
        uint64[] calldata _fromChains,
        address[] calldata _tokens,
        uint32[] calldata _ratios,
        uint32[] calldata _slippages
    ) external {
        emit WithdrawalRequest(msg.sender, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
    }

}