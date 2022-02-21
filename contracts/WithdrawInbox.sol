// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./safeguard/Pauser.sol";

contract WithdrawInbox is Pauser {
    // min allowed max slippage uint32 value is slippage * 1M, eg. 0.5% -> 5000
    uint32 public minimalMaxSlippage;

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
     * NOTE: Each of your withdrawal request should have different _wdSeq.
     * NOTE: Tokens to withdraw within one withdrawal request should have the same symbol.
     * @param _wdSeq The unique sequence number to identify this withdrawal request.
     * @param _receiver The receiver address on _toChain.
     * @param _toChain The chain Id to receive the withdrawn tokens.
     * @param _fromChains The chain Ids to withdraw tokens.
     * @param _tokens The token to withdraw on each fromChain.
     * @param _ratios The withdrawal ratios of each token.
     * @param _slippages The max slippages of each token for cross-chain withdraw.
     */
    function withdraw(
        uint64 _wdSeq,
        address _receiver,
        uint64 _toChain,
        uint64[] calldata _fromChains,
        address[] calldata _tokens,
        uint32[] calldata _ratios,
        uint32[] calldata _slippages
    ) external whenNotPaused {
        require(_fromChains.length > 0, "empty withdrawal request");
        require(
            _tokens.length == _fromChains.length &&
                _ratios.length == _fromChains.length &&
                _slippages.length == _fromChains.length,
            "length mismatch"
        );
        for (uint256 i = 0; i < _ratios.length; i++) {
            require(_ratios[i] > 0 && _ratios[i] <= 1e8, "invalid ratio");
            require(_slippages[i] >= minimalMaxSlippage, "slippage too small");
        }
        emit WithdrawalRequest(_wdSeq, msg.sender, _receiver, _toChain, _fromChains, _tokens, _ratios, _slippages);
    }

    function setMinimalMaxSlippage(uint32 _minimalMaxSlippage) external onlyOwner {
        minimalMaxSlippage = _minimalMaxSlippage;
    }
}
