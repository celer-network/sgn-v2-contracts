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

interface IWETH {
    function withdraw(uint256) external;
}

contract Pool is Signers, ReentrancyGuard, Pauser {
    using SafeERC20 for IERC20;

    uint64 public addseq; // ensure unique LiquidityAdded event, start from 1
    mapping(address => uint256) public minAdd; // add _amount must > minAdd

    // map of successful withdraws, if true means already withdrew money or added to delayedTransfers
    mapping(bytes32 => bool) public withdraws;

    uint256 public epochLength; // seconds
    mapping(address => uint256) public epochVolumes; // key is token
    mapping(address => uint256) public epochVolumeCaps; // key is token
    mapping(address => uint256) public lastOpTimestamps; // key is token

    struct delayedTransfer {
        address receiver;
        address token;
        uint256 amount;
        uint256 timestamp;
    }
    mapping(bytes32 => delayedTransfer) public delayedTransfers;
    mapping(address => uint256) public delayThresholds;
    uint256 public delayPeriod; // in seconds

    // erc20 wrap of gas token of this chain, eg. WETH, when relay ie. pay out,
    // if request.token equals this, will withdraw and send native token to receiver
    // note we don't check whether it's zero address. when this isn't set, and request.token
    // is all 0 address, guarantee fail
    address public nativeWrap;

    mapping(address => bool) public governors;

    // liquidity events
    event LiquidityAdded(
        uint64 seqnum,
        address provider,
        address token,
        uint256 amount // how many tokens were added
    );
    event WithdrawDone(
        bytes32 withdrawId,
        uint64 seqnum,
        address receiver,
        address token,
        uint256 amount,
        bytes32 refid
    );
    event DelayedTransferAdded(bytes32 id);
    event DelayedTransferExecuted(bytes32 id, address receiver, address token, uint256 amount);
    // gov events
    event GovernorAdded(address account);
    event GovernorRemoved(address account);
    event EpochLengthUpdated(uint256 length);
    event EpochVolumeUpdated(address token, uint256 cap);
    event DelayPeriodUpdated(uint256 period);
    event DelayThresholdUpdated(address token, uint256 threshold);
    event MinAddUpdated(address token, uint256 amount);

    constructor() {
        _addGovernor(msg.sender);
    }

    function addLiquidity(address _token, uint256 _amount) external nonReentrant whenNotPaused {
        addseq += 1;
        require(_amount > minAdd[_token], "amount too small");
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
        updateVolume(wdmsg.token, wdmsg.amount);
        uint256 delayThreshold = delayThresholds[wdmsg.token];
        if (delayThreshold > 0 && wdmsg.amount > delayThreshold) {
            addDelayedTransfer(wdId, wdmsg.receiver, wdmsg.token, wdmsg.amount);
        } else {
            IERC20(wdmsg.token).safeTransfer(wdmsg.receiver, wdmsg.amount);
        }
        emit WithdrawDone(wdId, wdmsg.seqnum, wdmsg.receiver, wdmsg.token, wdmsg.amount, wdmsg.refid);
    }

    function executeDelayedTransfer(bytes32 id) external whenNotPaused {
        delayedTransfer memory transfer = delayedTransfers[id];
        require(transfer.timestamp > 0, "transfer not exist");
        require(block.timestamp > transfer.timestamp + delayPeriod, "transfer still locked");
        delete delayedTransfers[id];
        if (transfer.token == nativeWrap && withdraws[id] == false) {
            // withdraw then transfer native to receiver
            IWETH(nativeWrap).withdraw(transfer.amount);
            (bool sent, ) = transfer.receiver.call{value: transfer.amount, gas: 50000}("");
            require(sent, "failed to relay native token");
        } else {
            IERC20(transfer.token).safeTransfer(transfer.receiver, transfer.amount);
        }
        emit DelayedTransferExecuted(id, transfer.receiver, transfer.token, transfer.amount);
    }

    function setEpochLength(uint256 _length) external onlyGovernor {
        epochLength = _length;
        emit EpochLengthUpdated(_length);
    }

    function setEpochVolumeCaps(address[] calldata _tokens, uint256[] calldata _caps) external onlyGovernor {
        require(_tokens.length == _caps.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            epochVolumeCaps[_tokens[i]] = _caps[i];
            emit EpochVolumeUpdated(_tokens[i], _caps[i]);
        }
    }

    function setDelayThresholds(address[] calldata _tokens, uint256[] calldata _thresholds) external onlyGovernor {
        require(_tokens.length == _thresholds.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            delayThresholds[_tokens[i]] = _thresholds[i];
            emit DelayThresholdUpdated(_tokens[i], _thresholds[i]);
        }
    }

    function setDelayPeriod(uint256 _period) external onlyGovernor {
        delayPeriod = _period;
        emit DelayPeriodUpdated(_period);
    }

    function setMinAdd(address[] calldata _tokens, uint256[] calldata _amounts) external onlyGovernor {
        require(_tokens.length == _amounts.length, "length mismatch");
        for (uint256 i = 0; i < _tokens.length; i++) {
            minAdd[_tokens[i]] = _amounts[i];
            emit MinAddUpdated(_tokens[i], _amounts[i]);
        }
    }

    function updateVolume(address _token, uint256 _amount) internal {
        if (epochLength == 0) {
            return;
        }
        uint256 cap = epochVolumeCaps[_token];
        if (cap == 0) {
            return;
        }
        uint256 volume = epochVolumes[_token];
        uint256 timestamp = block.timestamp;
        uint256 epochStartTime = (timestamp / epochLength) * epochLength;
        if (lastOpTimestamps[_token] < epochStartTime) {
            volume = _amount;
        } else {
            volume += _amount;
        }
        require(volume <= cap, "volume exceeds cap");
        epochVolumes[_token] = volume;
        lastOpTimestamps[_token] = timestamp;
    }

    function addDelayedTransfer(
        bytes32 id,
        address receiver,
        address token,
        uint256 amount
    ) internal {
        // note: rely on caller for id uniquess
        // current ids are relay transfer id and withdrawal id
        delayedTransfers[id] = delayedTransfer({
            receiver: receiver,
            token: token,
            amount: amount,
            timestamp: block.timestamp
        });
        emit DelayedTransferAdded(id);
    }

    // set nativeWrap, for relay requests, if token == nativeWrap, will withdraw first then transfer native to receiver
    function setWrap(address _weth) external onlyOwner {
        nativeWrap = _weth;
    }

    modifier onlyGovernor() {
        require(isGovernor(msg.sender), "Caller is not governor");
        _;
    }

    function isGovernor(address _account) public view returns (bool) {
        return governors[_account];
    }

    function addGovener(address _account) public onlyOwner {
        _addGovernor(_account);
    }

    function removeGovener(address _account) public onlyOwner {
        _removeGovernor(_account);
    }

    function renounceGovener() public {
        _removeGovernor(msg.sender);
    }

    function _addGovernor(address _account) private {
        require(!isGovernor(_account), "Account is already governor");
        governors[_account] = true;
        emit GovernorAdded(_account);
    }

    function _removeGovernor(address _account) private {
        require(isGovernor(_account), "Account is not governor");
        governors[_account] = false;
        emit GovernorRemoved(_account);
    }
}
