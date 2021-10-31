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

    uint256 epochLength;
    mapping(address => uint256) public epochVolumes;
    mapping(address => uint256) public epochVolumeCaps;
    mapping(address => uint256) public lastOpBlks;

    mapping(address => bool) public governors;

    // liquidity events
    event LiquidityAdded(
        uint64 seqnum,
        address provider,
        address token,
        uint256 amount // how many tokens were added
    );
    event WithdrawDone(bytes32 withdrawId, uint64 seqnum, address receiver, address token, uint256 amount);
    // gov events
    event GovernorAdded(address account);
    event GovernorRemoved(address account);
    event EpochLengthUpdated(uint256 length);
    event EpochVolumeUpdated(address token, uint256 cap);

    constructor() {
        _addGovernor(msg.sender);
    }

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
        updateVolume(wdmsg.token, wdmsg.amount);
        emit WithdrawDone(wdId, wdmsg.seqnum, wdmsg.receiver, wdmsg.token, wdmsg.amount);
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

    function updateVolume(address _token, uint256 _amount) internal {
        if (epochLength == 0) {
            return;
        }
        uint256 cap = epochVolumeCaps[_token];
        if (cap == 0) {
            return;
        }
        uint256 volume = epochVolumes[_token];
        uint256 blkNum = block.number;
        uint256 epochStartBlk = (blkNum / epochLength) * epochLength;
        if (lastOpBlks[_token] < epochStartBlk) {
            volume = _amount;
        } else {
            volume += _amount;
        }
        require(volume <= cap, "volume exceeds cap");
        epochVolumes[_token] = volume;
        lastOpBlks[_token] = blkNum;
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
