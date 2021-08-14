// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./DPoS.sol";
import "./libraries/PbSgn.sol";

/**
 * @title Sidechain contract of SGN
 */
contract SGN is Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable celr;
    DPoS public immutable dpos;
    mapping(address => uint256) public subscriptionDeposits;
    uint256 public servicePool;
    mapping(address => uint256) public redeemedServiceReward;
    mapping(address => bytes) public sidechainAddrMap;

    /* Events */
    event UpdateSidechainAddr(
        address indexed candidate,
        bytes indexed oldSidechainAddr,
        bytes indexed newSidechainAddr
    );
    event AddSubscriptionBalance(address indexed consumer, uint256 amount);
    event RedeemReward(
        address indexed receiver,
        uint256 cumulativeMiningReward,
        uint256 serviceReward,
        uint256 servicePool
    );

    /**
     * @notice SGN constructor
     * @dev Need to deploy DPoS contract first before deploying SGN contract
     * @param _celrAddress address of Celer Token Contract
     * @param _dposAddress address of DPoS Contract
     */
    constructor(address _celrAddress, DPoS _dposAddress) {
        celr = IERC20(_celrAddress);
        dpos = _dposAddress;
    }

    /**
     * @notice Throws if SGN sidechain is not valid
     * @dev Check this before sidechain's operations
     */
    modifier onlyValidSidechain() {
        require(dpos.isValidDPoS(), "DPoS is not valid");
        _;
    }

    /**
     * @notice Update sidechain address
     * @dev Note that the "sidechain address" here means the address in the offchain sidechain system,
         which is different from the sidechain contract address
     * @param _sidechainAddr the new address in the offchain sidechain system
     */
    function updateSidechainAddr(bytes calldata _sidechainAddr) external {
        address msgSender = msg.sender;

        (bool initialized, , , uint256 status, , ) = dpos.getCandidateInfo(msgSender);
        require(status == uint256(DPoS.CandidateStatus.Unbonded), "msg.sender is not unbonded");
        require(initialized, "Candidate is not initialized");

        bytes memory oldSidechainAddr = sidechainAddrMap[msgSender];
        sidechainAddrMap[msgSender] = _sidechainAddr;

        emit UpdateSidechainAddr(msgSender, oldSidechainAddr, _sidechainAddr);
    }

    /**
     * @notice Subscribe the guardian service
     * @param _amount subscription fee paid along this function call in CELR tokens
     */
    function subscribe(uint256 _amount) external whenNotPaused onlyValidSidechain {
        address msgSender = msg.sender;

        servicePool = servicePool + _amount;
        subscriptionDeposits[msgSender] = subscriptionDeposits[msgSender] + _amount;

        celr.safeTransferFrom(msgSender, address(this), _amount);

        emit AddSubscriptionBalance(msgSender, _amount);
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
