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
     * @param _receiver The receiver address on _toChain.
     * @param _toChain The chain Id to receive the withdrawn tokens.
     * @param _fromChains The chain Ids to withdraw tokens.
     * @param _tokens The token to withdraw on each fromChain.
     * @param _ratios The withdrawal ratios of each token.
     * @param _slippages The max slippages of each token for cross-chain withdraw.
     */
    function withdraw(
        address _receiver,
        uint64 _toChain,
        uint64[] calldata _fromChains,
        address[] calldata _tokens,
        uint32[] calldata _ratios,
        uint32[] calldata _slippages
    ) external {
        require(_fromChains.length == _tokens.length, "length mismatch");
        require(_ratios.length == _tokens.length, "length mismatch");
        require(_slippages.length == _tokens.length, "length mismatch");
        emit WithdrawalRequest(msg.sender, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
    }

}