// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Signers.sol";
import "./libraries/PbPool.sol";

// add liquidity and withdraw
// withdraw can be used by user or liquidity provider

contract Pool is Signers {
    using SafeERC20 for IERC20;

    uint64 addseq; // ensure unique LiquidityAdded event, start from 1
    // map of successful withdraws, if true means already withdrew money
    mapping(bytes32 => bool) public withdraws;

    event LiquidityAdded(
        uint64 chainId,
        uint64 seqnum,
        address provider,
        address token,
        uint256 amount // how many tokens were added
    );

    event WithdrawDone(
        bytes32 withdrawId,
        uint64 chainid,
        uint64 seqnum,
        address receiver,
        address token,
        uint256 amount
    );

    constructor(bytes memory _signers) Signers(_signers) {}

    function add_liquidity(
        address _token,
        uint256 _amount
    ) external {
        addseq += 1;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit LiquidityAdded(
            uint64(block.chainid),
            addseq,
            msg.sender,
            _token,
            _amount
        );
    }

    function withdraw(
        bytes calldata _wdmsg,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) external {
        verifySigs(_wdmsg, _curss, _sigs);
        // decode and check wdmsg
        PbPool.WithdrawMsg memory wdmsg = PbPool.decWithdrawMsg(_wdmsg);
        require(wdmsg.chainid == block.chainid, "dst chainId mismatch");
        bytes32 wdId = keccak256(
            abi.encodePacked(
                wdmsg.chainid,
                wdmsg.seqnum,
                wdmsg.receiver,
                wdmsg.token,
                wdmsg.amount
            )
        );
        require(withdraws[wdId] == false, "withdraw already succeeded");
        withdraws[wdId] = true;
        IERC20(wdmsg.token).safeTransfer(wdmsg.receiver, wdmsg.amount);
        emit WithdrawDone(
            wdId,
            wdmsg.chainid,
            wdmsg.seqnum,
            wdmsg.receiver,
            wdmsg.token,
            wdmsg.amount
        );
    }
}
