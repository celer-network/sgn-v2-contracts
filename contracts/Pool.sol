// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/PbPool.sol";
import "./Signers.sol";
import "./Pauser.sol";

// add liquidity and withdraw
// withdraw can be used by user or liquidity provider

contract Pool is Signers, ReentrancyGuard, Pauser {
    using SafeERC20 for IERC20;

    uint64 public addseq; // ensure unique LiquidityAdded event, start from 1
    // map of successful withdraws, if true means already withdrew money
    mapping(bytes32 => bool) public withdraws;

    event LiquidityAdded(
        uint64 seqnum,
        address provider,
        address token,
        uint256 amount // how many tokens were added
    );

    event WithdrawDone(bytes32 withdrawId, uint64 seqnum, address receiver, address token, uint256 amount);

    function addLiquidity(address _token, uint256 _amount) external nonReentrant whenNotPaused {
        addseq += 1;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit LiquidityAdded(addseq, msg.sender, _token, _amount);
    }

    function withdraw(
        bytes calldata _wdmsg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external whenNotPaused {
        verifySigs(_wdmsg, _sigs, _signers, _powers);
        // decode and check wdmsg
        PbPool.WithdrawMsg memory wdmsg = PbPool.decWithdrawMsg(_wdmsg);
        require(wdmsg.chainid == block.chainid, "dst chainId mismatch");
        bytes32 wdId = keccak256(
            abi.encodePacked(wdmsg.chainid, wdmsg.seqnum, wdmsg.receiver, wdmsg.token, wdmsg.amount)
        );
        require(withdraws[wdId] == false, "withdraw already succeeded");
        withdraws[wdId] = true;
        IERC20(wdmsg.token).safeTransfer(wdmsg.receiver, wdmsg.amount);
        emit WithdrawDone(wdId, wdmsg.seqnum, wdmsg.receiver, wdmsg.token, wdmsg.amount);
    }
}
