// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/PbBridge.sol";
import "./Pool.sol";

interface IWETH {
    function withdraw(uint256) external;
}

contract Bridge is Pool {
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
        bytes32 srcTransferId
    );

    mapping(bytes32 => bool) public transfers;
    mapping(address => uint256) public minSend; // send _amount must > minSend

    // min allowed max slippage uint32 value is slippage * 1M, eg. 0.5% -> 5000
    uint32 public mams;

    // erc20 wrap of gas token of this chain, eg. WETH, when relay ie. pay out,
    // if request.token equals this, will withdraw and send native token to receiver
    // note we don't check whether it's zero address. when this isn't set, and request.token
    // is all 0 address, guarantee fail
    address public nativeWrap;

    constructor(bytes memory _signers) Pool(_signers) {}

    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage // slippage * 1M, eg. 0.5% -> 5000
    ) external nonReentrant {
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

    function relay(
        bytes calldata _relayRequest,
        bytes calldata _curss,
        bytes[] calldata _sigs
    ) external {
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
                request.srcTransferId
            )
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        if (request.token == nativeWrap) {
            // withdraw then transfer native to receiver
            IWETH(nativeWrap).withdraw(request.amount);
            payable(request.receiver).transfer(request.amount);
        } else {
            IERC20(request.token).safeTransfer(request.receiver, request.amount);
        }

        emit Relay(
            transferId,
            request.sender,
            request.receiver,
            request.token,
            request.amount,
            request.srcChainId,
            request.srcTransferId
        );
    }

    function setMinSend(address[] calldata tokens, uint256[] calldata minsend) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            minSend[tokens[i]] = minsend[i];
        }
    }

    function setMinSlippage(uint32 minslip) external onlyOwner {
        mams = minslip;
    }

    // set nativeWrap, for relay requests, if token == nativeWrap, will withdraw first then transfer native to receiver
    function setWrap(address _weth) external onlyOwner {
        nativeWrap = _weth;
    }

    // This is needed to receive ETH when calling `IWETH.withdraw`
    receive() external payable {}

    fallback() external payable {}
}
