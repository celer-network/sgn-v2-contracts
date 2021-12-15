// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./proto/PbSamples.sol";
import "../AppTemplate.sol";

abstract contract BatchTransfer is AppTemplate {
    using SafeERC20 for IERC20;

    // ============== functions on source chain ==============

    function batchTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage,
        bytes calldata _message
    ) external {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        PbSamples.AcctAmts memory acctAmts = PbSamples.decAcctAmts(_message);
        uint256 totalAmt;
        for (uint256 i = 0; i < acctAmts.pairs.length; i++) {
            totalAmt += acctAmts.pairs[i].amount;
        }
        uint256 minRecv = _amount - (_amount * _maxSlippage) / 1e6;
        require(minRecv > totalAmt, "invalid maxSlippage");
        transferWithMessage(_receiver, _token, _amount, _dstChainId, _maxSlippage, _message);
    }

    // ============== functions on destination chain ==============

    function handleRelayMessage(
        address,
        address _token,
        uint256 _amount,
        uint64,
        bytes memory _message
    ) internal override {
        PbSamples.AcctAmts memory acctAmts = PbSamples.decAcctAmts(_message);
        uint256 totalAmt;
        for (uint256 i = 0; i < acctAmts.pairs.length; i++) {
            PbSamples.AcctAmtPair memory pair = acctAmts.pairs[i];
            IERC20(_token).safeTransfer(pair.account, pair.amount);
            totalAmt += pair.amount;
        }
        uint256 fee = _amount - totalAmt;
        IERC20(_token).safeTransfer(msg.sender, fee);
    }
}
