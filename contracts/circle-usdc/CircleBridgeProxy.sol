// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FeeOperator.sol";
import "../interfaces/ICircleBridge.sol";
import "../safeguard/Governor.sol";
import "../safeguard/Pauser.sol";

contract CircleBridgeProxy is FeeOperator, Governor, Pauser, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable circleBridge;

    uint32 public feePercGlobal; //in 1e6
    // chainId => feePercOverride, support override fee perc by dst chain
    mapping(uint64 => uint32) public feePercOverride;
    /// per dest chain id executor fee in this chain's USDC token
    mapping(uint64 => uint256) public dstTxFee;

    // 0 is regarded as not registered. Set to a negative value if target domain is actually 0.
    mapping(uint64 => int32) public chidToDomain;

    event FeePercUpdated(uint64[] chainIds, uint32[] feePercs);
    event TxFeeUpdated(uint64[] chainIds, uint256[] fees);
    event ChidToDomainUpdated(uint64[] chainIds, int32[] domains);
    event Deposited(
        address sender,
        bytes32 recipient,
        uint64 dstChid,
        uint256 amount,
        uint256 txFee,
        uint256 percFee,
        uint64 nonce
    );

    constructor(address _circleBridge, address _feeCollector) FeeOperator(_feeCollector) {
        circleBridge = _circleBridge;
    }

    function depositForBurn(
        uint256 _amount,
        uint64 _dstChid,
        bytes32 _mintRecipient,
        address _burnToken
    ) external nonReentrant whenNotPaused returns (uint64 _nonce) {
        int32 dstDomain = chidToDomain[_dstChid];
        require(dstDomain != 0, "dst domain not registered");
        if (dstDomain < 0) {
            dstDomain = 0; // a negative value indicates the target domain is 0 actually.
        }
        (uint256 fee, uint256 txFee, uint256 percFee) = totalFee(_amount, _dstChid);
        require(_amount > fee, "fee not covered");

        IERC20(_burnToken).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 bridgeAmt = _amount - fee;
        IERC20(_burnToken).safeIncreaseAllowance(circleBridge, bridgeAmt);
        _nonce = ICircleBridge(circleBridge).depositForBurn(bridgeAmt, uint32(dstDomain), _mintRecipient, _burnToken);
        IERC20(_burnToken).safeApprove(circleBridge, 0);
        emit Deposited(msg.sender, _mintRecipient, _dstChid, _amount, txFee, percFee, _nonce);
    }

    function totalFee(uint256 _amount, uint64 _dstChid)
        public
        view
        returns (
            uint256 _fee,
            uint256 _txFee,
            uint256 _percFee
        )
    {
        uint32 feePerc = feePercOverride[_dstChid];
        if (feePerc == 0) {
            feePerc = feePercGlobal;
        }
        _txFee = dstTxFee[_dstChid];
        _percFee = (_amount * feePerc) / 1e6;
        _fee = _txFee + _percFee;
    }

    function setFeePerc(uint64[] calldata _chainIds, uint32[] calldata _feePercs) external onlyGovernor {
        require(_chainIds.length == _feePercs.length, "length mismatch");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            require(_feePercs[i] < 1e6, "fee percentage too large");
            if (_chainIds[i] == 0) {
                feePercGlobal = _feePercs[i];
            } else {
                feePercOverride[_chainIds[i]] = _feePercs[i];
            }
        }
        emit FeePercUpdated(_chainIds, _feePercs);
    }

    function setTxFee(uint64[] calldata _chainIds, uint256[] calldata _fees) external onlyGovernor {
        require(_chainIds.length == _fees.length, "length mismatch");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            dstTxFee[_chainIds[i]] = _fees[i];
        }
        emit TxFeeUpdated(_chainIds, _fees);
    }

    function setChidToDomain(uint64[] calldata _chainIds, int32[] calldata _domains) external onlyGovernor {
        require(_chainIds.length == _domains.length, "length mismatch");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            chidToDomain[_chainIds[i]] = _domains[i];
        }
        emit ChidToDomainUpdated(_chainIds, _domains);
    }
}
