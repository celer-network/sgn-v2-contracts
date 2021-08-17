// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./DPoS.sol";

/**
 * @title Sidechain contract of SGN
 * TODO: complete implementation of reward and withdrawal
 */
contract SGN is Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable celr;
    DPoS public immutable dpos;
    mapping(address => uint256) public deposits;
    mapping(address => bytes) public sgnAddrs;

    /* Events */
    event SgnAddrUpdate(address indexed valAddr, bytes indexed oldAddr, bytes indexed newAddr);
    event Deposit(address indexed account, uint256 amount);

    /**
     * @notice SGN constructor
     * @dev Need to deploy DPoS contract first before deploying SGN contract
     * @param _celrAddr address of Celer Token Contract
     * @param _dpos address of DPoS Contract
     */
    constructor(address _celrAddr, DPoS _dpos) {
        celr = IERC20(_celrAddr);
        dpos = _dpos;
    }

    /**
     * @notice Update sgn address
     * @param _sgnAddr the new address in the layer 2 SGN
     */
    function updateSgnAddr(bytes calldata _sgnAddr) external {
        address valAddr = msg.sender;

        DPoS.ValidatorStatus status = dpos.getValidatorStatus(valAddr);
        require(status == DPoS.ValidatorStatus.Unbonded, "Not unbonded validator");

        bytes memory oldAddr = sgnAddrs[valAddr];
        sgnAddrs[valAddr] = _sgnAddr;

        emit SgnAddrUpdate(valAddr, oldAddr, _sgnAddr);
    }

    /**
     * @notice Deposit to SGN
     * @param _amount subscription fee paid along this function call in CELR tokens
     */
    function deposit(uint256 _amount) external whenNotPaused {
        address msgSender = msg.sender;
        deposits[msgSender] = deposits[msgSender] + _amount;
        celr.safeTransferFrom(msgSender, address(this), _amount);
        emit Deposit(msgSender, _amount);
    }

    /**
     * @notice Called by the owner to pause contract
     * @dev emergency use only
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Called by the owner to unpause contract
     * @dev emergency use only
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Owner drains one type of tokens when the contract is paused
     * @dev emergency use only
     * @param _amount drained token amount
     */
    function drainToken(uint256 _amount) external whenPaused onlyOwner {
        celr.safeTransfer(msg.sender, _amount);
    }
}
