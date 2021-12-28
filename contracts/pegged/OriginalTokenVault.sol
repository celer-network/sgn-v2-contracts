// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISigsVerifier.sol";
import "../interfaces/IWETH.sol";
import "../libraries/PbPegged.sol";
import "../safeguard/Pauser.sol";
import "../safeguard/VolumeControl.sol";
import "../safeguard/DelayedTransfer.sol";

/**
 * @title the vault to deposit and withdraw original tokens
 * @dev Work together with PeggedTokenBridge contracts deployed at remote chains
 */
contract OriginalTokenVault is ReentrancyGuard, Pauser, VolumeControl, DelayedTransfer {
    using SafeERC20 for IERC20;

    ISigsVerifier public immutable sigsVerifier;

    mapping(bytes32 => bool) public records;

    mapping(address => uint256) public minDeposit;
    mapping(address => uint256) public maxDeposit;

    address public nativeWrap;

    event Deposited(
        bytes32 depositId,
        address depositor,
        address token,
        uint256 amount,
        uint64 mintChainId,
        address mintAccount
    );
    event Withdrawn(
        bytes32 withdrawId,
        address receiver,
        address token,
        uint256 amount,
        uint64 refChainId,
        bytes32 refId,
        address burnAccount
    );
    event MinDepositUpdated(address token, uint256 amount);
    event MaxDepositUpdated(address token, uint256 amount);

    constructor(ISigsVerifier _sigsVerifier) {
        sigsVerifier = _sigsVerifier;
    }

    /**
     * @notice Lock original tokens to trigger mint at a remote chain's PeggedTokenBridge
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _mintAccount destination account to receive minted tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external nonReentrant whenNotPaused {
        bytes32 depId = _deposit(_token, _amount, _mintChainId, _mintAccount, _nonce);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(depId, msg.sender, _token, _amount, _mintChainId, _mintAccount);
    }

    function depositNative(
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external payable nonReentrant whenNotPaused {
        require(msg.value == _amount, "Amount mismatch");
        require(nativeWrap != address(0), "Native wrap not set");
        bytes32 depId = _deposit(nativeWrap, _amount, _mintChainId, _mintAccount, _nonce);
        IWETH(nativeWrap).deposit{value: _amount}();
        emit Deposited(depId, msg.sender, nativeWrap, _amount, _mintChainId, _mintAccount);
    }

    function _deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) private returns (bytes32) {
        require(_amount > minDeposit[_token], "amount too small");
        require(maxDeposit[_token] == 0 || _amount <= maxDeposit[_token], "amount too large");
        bytes32 depId = keccak256(
            // len = 20 + 20 + 32 + 8 + 20 + 8 + 8 = 128
            abi.encodePacked(msg.sender, _token, _amount, _mintChainId, _mintAccount, _nonce, uint64(block.chainid))
        );
        require(records[depId] == false, "record exists");
        records[depId] = true;
        return depId;
    }

    /**
     * @notice Withdraw locked tokens triggered by burn at a remote chain's PeggedTokenBridge
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external whenNotPaused {
        bytes32 domain = keccak256(abi.encodePacked(block.chainid, address(this), "Withdraw"));
        sigsVerifier.verifySigs(abi.encodePacked(domain, _request), _sigs, _signers, _powers);
        PbPegged.Withdraw memory request = PbPegged.decWithdraw(_request);
        bytes32 wdId = keccak256(
            // len = 20 + 20 + 32 + 20 + 8 + 32 = 132
            abi.encodePacked(
                request.receiver,
                request.token,
                request.amount,
                request.burnAccount,
                request.refChainId,
                request.refId
            )
        );
        require(records[wdId] == false, "record exists");
        records[wdId] = true;
        _updateVolume(request.token, request.amount);
        uint256 delayThreshold = delayThresholds[request.token];
        if (delayThreshold > 0 && request.amount > delayThreshold) {
            _addDelayedTransfer(wdId, request.receiver, request.token, request.amount);
        } else {
            _sendToken(request.receiver, request.token, request.amount);
        }
        emit Withdrawn(
            wdId,
            request.receiver,
            request.token,
            request.amount,
            request.refChainId,
            request.refId,
            request.burnAccount
        );
    }

    function executeDelayedTransfer(bytes32 id) external whenNotPaused {
        delayedTransfer memory transfer = _executeDelayedTransfer(id);
        _sendToken(transfer.receiver, transfer.token, transfer.amount);
    }

    function setMinDeposit(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            minDeposit[_tokens[i]] = _amounts[i];
            emit MinDepositUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setMaxDeposit(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            maxDeposit[_tokens[i]] = _amounts[i];
            emit MaxDepositUpdated(_tokens[i], _amounts[i]);
        }
    }

    function setWrap(address _weth) external onlyOwner {
        nativeWrap = _weth;
    }

    function _sendToken(
        address _receiver,
        address _token,
        uint256 _amount
    ) private {
        if (_token == nativeWrap) {
            // withdraw then transfer native to receiver
            IWETH(nativeWrap).withdraw(_amount);
            (bool sent, ) = _receiver.call{value: _amount, gas: 50000}("");
            require(sent, "failed to send native token");
        } else {
            IERC20(_token).safeTransfer(_receiver, _amount);
        }
    }

    receive() external payable {}
}
