// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/PbBridge.sol";
import "./Pool.sol";

contract Bridge is Pool, Ownable {
    using SafeERC20 for IERC20;

    event Send(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 dstChainId,
        uint64 nonce,
        uint32 maxSlippage
    );

    event Relay(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 srcChainId,
        uint64 nonce,
        bytes32 srcTransferId
    );

    mapping(bytes32 => bool) public transfers;
    mapping(address => uint256) public minSend; // send _amount must > minSend

    // min allowed max slippage uint32 value is slippage * 1M, eg. 0.5% -> 5000
    uint32 mams;

    constructor(bytes memory _signers) Pool(_signers) {}

    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage // slippage * 1M, eg. 0.5% -> 5000
    ) external {
        require(_amount > minSend[_token], "amount too small");
        require(_maxSlippage > mams, "max slippage too small");
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, _receiver, _token, _amount, _dstChainId, _nonce, block.chainid)
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Send(transferId, msg.sender, _receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
    }

    function relay(bytes calldata _relayRequest, bytes calldata _curss, bytes[] calldata _sigs) external {
        verifySigs(_relayRequest, _curss, _sigs);
        PbBridge.Relay memory request = PbBridge.decRelay(_relayRequest);
        require(request.dstChainId == block.chainid, "dst chainId not match");

        bytes32 transferId = keccak256(
            abi.encodePacked(
                request.sender,
                request.receiver,
                request.token,
                request.amount,
                request.srcChainId,
                request.dstChainId,
                request.srcTransferId,
                request.nonce
            )
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        IERC20(request.token).safeTransfer(request.receiver, request.amount);

        emit Relay(
            transferId,
            request.sender,
            request.receiver,
            request.token,
            request.amount,
            request.srcChainId,
            request.nonce,
            request.srcTransferId
        );
    }

    function setMinSend(address[] calldata tokens, uint256[] calldata minsend) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            minSend[tokens[i]] = minsend[i];
        }
    }
    // chainid not in chainIds is not touched
    function setMinSlippage(uint32[] minslip) external onlyOwner {
        mams = minslip;
    }
}
