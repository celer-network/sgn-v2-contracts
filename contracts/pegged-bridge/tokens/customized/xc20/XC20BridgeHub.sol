// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IXC20BridgeHub.sol";

/**
 * @title A hub for managing swapping between canonical XC20 tokens and intermediary bridge tokens.
 */
contract XC20BridgeHub is Ownable, IXC20BridgeHub, Pausable {
    using SafeERC20 for IERC20;

    struct TokenPair {
        address bridgeToken;
        address canonicalToken;
        bool paused;
        uint256 limit; // Max amount of bridge token allowed in the hub.
    }
    address[] public bridgeTokens;
    // bridge token address => TokenPair
    mapping(address => TokenPair) public tokenPairMap;

    event TokenPairAdded(address indexed bridgeToken, address indexed canonicalToken, uint256 limit);
    event TokenPairRemoved(address indexed bridgeToken, address indexed canonicalToken);
    event TokenPairPaused(address indexed bridgeToken, address indexed canonicalToken);
    event TokenPairUnpaused(address indexed bridgeToken, address indexed canonicalToken);
    event TokenPairLimitSet(address indexed bridgeToken, address indexed canonicalToken, uint256 limit);
    event BridgeSwappedForCanonical(
        address indexed bridgeToken,
        address indexed canonicalToken,
        uint256 bridgeTokenAmount,
        uint256 refund,
        uint256 canonicalTokenAmount
    );
    event CanonicalSwappedForBridge(
        address indexed bridgeToken,
        address indexed canonicalToken,
        uint256 canonicalTokenAmount,
        uint256 refund,
        uint256 bridgeTokenAmount
    );

    /**
     * @dev Pauses a token pair.
     * @param _bridgeToken The bridge token of the pair.
     */
    function pauseTokenPair(address _bridgeToken) external onlyOwner {
        TokenPair storage pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        require(!pair.paused, "XC20BridgeHub: token pair already paused");
        pair.paused = true;
        emit TokenPairPaused(_bridgeToken, pair.canonicalToken);
    }

    /**
     * @dev Unpauses a token pair.
     * @param _bridgeToken The bridge token of the pair.
     */
    function unpauseTokenPair(address _bridgeToken) external onlyOwner {
        TokenPair storage pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        require(pair.paused, "XC20BridgeHub: token pair already unpaused");
        pair.paused = false;
        emit TokenPairUnpaused(_bridgeToken, pair.canonicalToken);
    }

    /**
     * @dev Sets a token pair limit.
     * @param _bridgeToken The bridge token of the pair.
     * @param _limit The max amount of bridge token allowed in the hub.
     */
    function setTokenPairLimit(address _bridgeToken, uint256 _limit) external onlyOwner {
        TokenPair storage pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        pair.limit = _limit;
        emit TokenPairLimitSet(_bridgeToken, pair.canonicalToken, _limit);
    }

    /**
     * @dev Adds a token pair.
     * @param _bridgeToken The bridge token of the pair.
     * @param _canonicalToken The canonical token of the pair.
     * @param _limit The max amount of bridge token allowed in the hub.
     */
    function addTokenPair(
        address _bridgeToken,
        address _canonicalToken,
        uint256 _limit
    ) external onlyOwner {
        require(_bridgeToken != address(0), "XC20BridgeHub: bridge token is zero address");
        require(tokenPairMap[_bridgeToken].bridgeToken == address(0), "XC20BridgeHub: bridge token exists");
        require(
            IERC20Metadata(_bridgeToken).decimals() == IERC20Metadata(_canonicalToken).decimals(),
            "XC20BridgeHub: decimals mismatch"
        );

        TokenPair memory pair = TokenPair(address(_bridgeToken), address(_canonicalToken), false, _limit);
        bridgeTokens.push(_bridgeToken);
        tokenPairMap[_bridgeToken] = pair;
        emit TokenPairAdded(_bridgeToken, _canonicalToken, _limit);
    }

    /**
     * @dev Removes a token pair.
     * @param _bridgeToken The bridge token of the pair.
     */
    function removeTokenPair(address _bridgeToken) external onlyOwner {
        TokenPair memory pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        delete tokenPairMap[_bridgeToken];
        uint256 index = bridgeTokens.length;
        for (uint256 i = 0; i < bridgeTokens.length; i++) {
            if (bridgeTokens[i] == _bridgeToken) {
                index = i;
                break;
            }
        }
        if (index < bridgeTokens.length) {
            delete bridgeTokens[index];
        }
        emit TokenPairRemoved(_bridgeToken, pair.canonicalToken);
    }

    /**
     * @dev Returns all token pairs.
     */
    function getAllTokenPairs() external view returns (TokenPair[] memory) {
        TokenPair[] memory pairs = new TokenPair[](bridgeTokens.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            pairs[i] = tokenPairMap[bridgeTokens[i]];
        }
        return pairs;
    }

    /**
     * @dev Swaps intermediary bridge token for canonical XC-20 token.
     * @param _bridgeToken The intermediary bridge token
     * @param _amount The amount to swap
     * @return The canonical token amount
     */
    function swapBridgeForCanonical(address _bridgeToken, uint256 _amount)
        external
        override
        whenNotPaused
        returns (uint256)
    {
        TokenPair memory pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        require(!pair.paused, "XC20BridgeHub: token pair paused");
        IERC20 bridgeErc20 = IERC20(_bridgeToken);
        require(
            pair.limit > 0 && (bridgeErc20.balanceOf(address(this))) + _amount <= pair.limit,
            "XC20BridgeHub: exceeds bridge limit"
        );

        address canonicalToken = pair.canonicalToken;
        uint256 delta = transferIn(_bridgeToken, _amount);
        (uint256 canonicalTokenAmount, uint256 refund) = calcTransferAmountWithDecimals(
            delta,
            IERC20Metadata(_bridgeToken).decimals(),
            IERC20Metadata(canonicalToken).decimals()
        );
        if (refund > 0) {
            IERC20(_bridgeToken).safeTransfer(msg.sender, refund);
        }
        if (canonicalTokenAmount > 0) {
            IERC20(pair.canonicalToken).safeTransfer(msg.sender, _amount);
        }
        emit BridgeSwappedForCanonical(_bridgeToken, canonicalToken, _amount, refund, canonicalTokenAmount);
        return canonicalTokenAmount;
    }

    /**
     * @dev Swaps canonical XC-20 token for intermediary bridge token.
     * @param _bridgeToken The intermediary bridge token
     * @param _amount The amount to swap
     * @return The bridge token amount
     */
    function swapCanonicalForBridge(address _bridgeToken, uint256 _amount)
        external
        override
        whenNotPaused
        returns (uint256)
    {
        TokenPair memory pair = tokenPairMap[_bridgeToken];
        require(pair.bridgeToken != address(0), "XC20BridgeHub: non-existent bridge token");
        require(!pair.paused, "XC20BridgeHub: token pair paused");

        address canonicalToken = pair.canonicalToken;
        uint256 delta = transferIn(canonicalToken, _amount);
        (uint256 bridgeTokenAmount, uint256 refund) = calcTransferAmountWithDecimals(
            delta,
            IERC20Metadata(canonicalToken).decimals(),
            IERC20Metadata(_bridgeToken).decimals()
        );
        if (refund > 0) {
            IERC20(canonicalToken).safeTransfer(msg.sender, refund);
        }
        if (bridgeTokenAmount > 0) {
            IERC20(_bridgeToken).safeTransfer(msg.sender, _amount);
        }
        emit CanonicalSwappedForBridge(_bridgeToken, canonicalToken, _amount, refund, bridgeTokenAmount);
        return bridgeTokenAmount;
    }

    /**
     * @dev Sets the paused status of the hub.
     * @param _paused Whether the hub should be paused
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
     * @dev Transfers the amount of tokens into the hub.
     * @param _token The token address
     * @param _amount The transfer amount
     * @return The balance change
     */
    function transferIn(address _token, uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    /**
     * @dev Calculates the transfer amount and if applicable, refund amount, taking into account the
     * difference between token decimals.
     * @param _amount The original amount
     * @param _aDecimals The decimals of token A
     * @param _bDecimals The decimals of token B
     */
    function calcTransferAmountWithDecimals(
        uint256 _amount,
        uint256 _aDecimals,
        uint256 _bDecimals
    ) internal pure returns (uint256 newAmount, uint256 refund) {
        if (_aDecimals > _bDecimals) {
            newAmount = _amount / (10**(_aDecimals - _bDecimals));
            refund = _amount - newAmount * (10**(_aDecimals - _bDecimals));
        } else if (_aDecimals < _bDecimals) {
            newAmount = _amount * (10**(_bDecimals - _aDecimals));
        } else {
            newAmount = _amount;
        }
    }

    // This account has to hold some amount of native currency in order to be eligible
    // to receive canonical x20 assets per Astar rule
    receive() external payable {}
}
