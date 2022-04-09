// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

interface INFTBridge {
    function sendMsg(uint64 _dstChid, address _receiver, uint256 _id, string calldata _uri) external payable;
    function totalFee(
        uint64 _dstChid,
        address _nft,
        uint256 _id
    ) external view returns (uint256);
}

// Multi-Chain Native NFT, same contract on all chains. User interacts with this directly.
contract MCNNFT is ERC721URIStorage {
    address public immutable nftBridge;

    constructor(
        string memory name_,
        string memory symbol_,
        address _nftBridge
    ) ERC721(name_, symbol_) {
        nftBridge = _nftBridge;
    }

    modifier onlyNftBridge() {
        require(msg.sender == nftBridge, "caller is not bridge");
        _;
    }

    function mint(
        address to,
        uint256 id,
        string memory uri
    ) external onlyNftBridge {
        _mint(to, id);
        _setTokenURI(id, uri);
    }

    // calls nft bridge to get total fee for crossChain msg.Value
    function totalFee(uint64 _dstChid, uint256 _id) external view returns (uint256) {
        return INFTBridge(nftBridge).totalFee(_dstChid, address(this), _id);
    }

    // burn ID on this chain and mint on dest chain
    function crossChain(uint64 _dstChid, uint256 _id, address _receiver) external payable {
        string memory _uri = tokenURI(_id);
        _burn(_id);
        INFTBridge(nftBridge).sendMsg{value: msg.value}(_dstChid, _receiver, _id, _uri);
    }
}
