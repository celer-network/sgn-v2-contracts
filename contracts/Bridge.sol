// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/PbBridge.sol";
import "./Pool.sol";

contract Bridge is Pool {
    using SafeERC20 for IERC20;

    // liquidity events
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
    // gov events
    event MinSendUpdated(address token, uint256 amount);
    event MaxSendUpdated(address token, uint256 amount);

    mapping(bytes32 => bool) public transfers;
    mapping(address => uint256) public minSend; // send _amount must > minSend
    mapping(address => uint256) public maxSend;

    // min allowed max slippage uint32 value is slippage * 1M, eg. 0.5% -> 5000
    uint32 public minimalMaxSlippage;

    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage // slippage * 1M, eg. 0.5% -> 5000
    ) external nonReentrant whenNotPaused {
        require(_amount > minSend[_token], "amount too small");
        require(maxSend[_token] == 0 || _amount <= maxSend[_token], "amount too large");
        require(_maxSlippage > minimalMaxSlippage, "max slippage too small");
        bytes32 transferId = keccak256(
            // uint64(block.chainid) for consistency as entire system uses uint64 for chain id
            abi.encodePacked(msg.sender, _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Send(transferId, msg.sender, _receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
    }

    function relay(
        bytes calldata _relayRequest,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external whenNotPaused {
        verifySigs(_relayRequest, _sigs, _signers, _powers);
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
        updateVolume(request.token, request.amount);
        uint256 delayThreshold = delayThresholds[request.token];
        if (delayThreshold > 0 && request.amount > delayThreshold) {
            addDelayedTransfer(transferId, request.receiver, request.token, request.amount);
        } else {
            if (request.token == nativeWrap) {
                // withdraw then transfer native to receiver
                IWETH(nativeWrap).withdraw(request.amount);
                (bool sent, ) = request.receiver.call{value: request.amount, gas: 50000}("");
                require(sent, "failed to relay native token");
            } else {
                IERC20(request.token).safeTransfer(request.receiver, request.amount);
            }
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

    function setMinSend(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            minSend[_tokens[i]] = _amounts[i];
            emit MinSendUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setMaxSend(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            maxSend[_tokens[i]] = _amounts[i];
            emit MaxSendUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setMinimalMaxSlippage(uint32 _minimalMaxSlippage) external onlyGovernor {
        minimalMaxSlippage = _minimalMaxSlippage;
    }

    // This is needed to receive ETH when calling `IWETH.withdraw`
    receive() external payable {}
}
