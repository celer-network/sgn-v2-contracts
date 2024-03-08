// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../libraries/BridgeTransferLib.sol";

// Interface for the canonical Circle token
interface IFiatToken is IERC20 {
    function mint(address to, uint256 amount) external;

    // Burns OWN tokens
    function burn(uint256 amount) external;
}

/**
 * @title Intermediary token that delegates to a canonical Circle token. With the functionality to
 * migrate minting / burning permissions to Circle in the future.
 */
contract CircleBridgeToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public bridge;
    address public immutable canonical; // canonical Circle token

    bool public migrated;
    uint64 public immutable origChainId;
    address public origChainWithdrawAddress;

    event BridgeUpdated(address bridge);
    event OrigChainWithdrawAddressUpdated(address origChainWithdrawAddress);
    event Migrated(bytes32 transferId, address origChainWithdrawAddress, uint256 totalSupply);

    modifier onlyBridge() {
        require(msg.sender == bridge, "caller is not bridge");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address bridge_,
        address canonical_,
        uint64 origChainId_
    ) ERC20(name_, symbol_) {
        bridge = bridge_;
        canonical = canonical_;
        origChainId = origChainId_;
    }

    function mint(address _to, uint256 _amount) external onlyBridge returns (bool) {
        require(!migrated, "already migrated");

        _mint(address(this), _amount); // totalSupply == bridge liquidity
        IFiatToken(canonical).mint(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) external onlyBridge returns (bool) {
        _burn(address(this), _amount);

        if (!migrated) {
            IERC20(canonical).safeTransferFrom(_from, address(this), _amount);
            IFiatToken(canonical).burn(_amount);
        }
        return true;
    }

    function updateBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit BridgeUpdated(bridge);
    }

    // to make compatible with BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(canonical).decimals();
    }

    function setOrigChainWithdrawAddress(address _origChainWithdrawAddress) external onlyOwner {
        origChainWithdrawAddress = _origChainWithdrawAddress;
        emit OrigChainWithdrawAddressUpdated(origChainWithdrawAddress);
    }

    function migrate() external onlyOwner {
        require(!migrated, "already migrated");

        migrated = true;

        uint256 supply = totalSupply();
        bytes32 transferId = BridgeTransferLib.sendTransfer(
            origChainWithdrawAddress,
            address(this),
            supply,
            origChainId,
            uint64(block.timestamp),
            0, // _maxSlippage
            BridgeTransferLib.BridgeSendType.PegV2Burn,
            bridge
        );
        emit Migrated(transferId, origChainWithdrawAddress, supply);
    }
}
