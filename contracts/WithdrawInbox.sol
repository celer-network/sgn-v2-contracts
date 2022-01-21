// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

contract WithdrawInbox {
    uint64 public wdseq; // ensure unique WithdrawalRequest event, start from 1
    // contract LP withdrawal request
    event WithdrawalRequest(
        uint64 seqNum,
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
        require(
            _tokens.length == _fromChains.length &&
                _ratios.length == _fromChains.length &&
                _slippages.length == _fromChains.length,
            "length mismatch"
        );
        wdseq += 1;
        emit WithdrawalRequest(wdseq, msg.sender, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
    }
}
