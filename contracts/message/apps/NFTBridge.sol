// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.9;

import "../framework/MessageReceiverApp.sol";
import "../interfaces/IMessageBus.sol";

// interface for NFT contract, ERC721 and metadata, only funcs needed by NFTBridge
interface INFT {
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    // we do not support NFT that charges transfer fees
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    // impl by NFToken contract, mint an NFT with id and uri to user or burn
    function mint(
        address to,
        uint256 id,
        string memory uri
    ) external;

    function burn(uint256 id) external;
}

/** @title NFT Bridge */
contract NFTBridge is MessageReceiverApp {
    /// per dest chain id executor fee in this chain's gas token
    mapping(uint64 => uint256) public destTxFee;

    enum MsgType {
        Mint,
        Withdraw
    }
    struct NFTMsg {
        MsgType msgType; // mint or withdraw
        address user; // receiver of minted or withdrawn NFT
        address nft; // NFT contract on mint/withdraw chain
        uint256 id; // token ID
        string uri; // tokenURI from source NFT
    }
    // emit in deposit or burn
    event Sent(address sender, address srcNft, uint256 id, uint64 dstChid, address receiver, address dstNft);
    // emit for mint or withdraw message
    event Received(address receiver, address nft, uint256 id, uint64 srcChid);

    constructor(address _msgBus) {
        messageBus = _msgBus;
    }

    /**
     * @notice totalFee returns gas token value to be set in user tx, includes both cbridge msg fee and executor fee on dest chain
     * @dev we use _nft address for user as it's same length so same msg cost
     * @param _dstChid dest chain ID
     * @param _nft address of source NFT contract
     * @param _id token ID to bridge (need to get accurate tokenURI length)
     * @return total fee needed for user tx
     */
    function totalFee(
        uint64 _dstChid,
        address _nft,
        uint256 _id
    ) external view returns (uint256) {
        string memory _uri = INFT(_nft).tokenURI(_id);
        bytes memory message = abi.encode(NFTMsg(MsgType.Mint, _nft, _nft, _id, _uri));
        return IMessageBus(messageBus).calcFee(message) + destTxFee[_dstChid];
    }

    // ===== called by user
    /**
     * @notice deposit locks user's NFT in this contract and send message to mint on dest chain
     * @param _nft address of source NFT contract
     * @param _id nft token ID to bridge
     * @param _dstChid dest chain ID
     * @param _receiver receiver address on dest chain
     * @param _dstNft dest chain NFT address
     * @param _dstBridge dest chain NFTBridge address, so we know what address should receive msg. we could save in map and not require this?
     */
    function deposit(
        address _nft,
        uint256 _id,
        uint64 _dstChid,
        address _receiver,
        address _dstNft,
        address _dstBridge
    ) external payable {
        INFT(_nft).transferFrom(msg.sender, address(this), _id);
        require(INFT(_nft).ownerOf(_id) == address(this), "transfer NFT failed");
        bytes memory message = abi.encode(NFTMsg(MsgType.Mint, _receiver, _dstNft, _id, INFT(_nft).tokenURI(_id)));
        uint256 fee = IMessageBus(messageBus).calcFee(message);
        require(msg.value >= fee + destTxFee[_dstChid], "insufficient fee");
        IMessageBus(messageBus).sendMessage{value: fee}(_dstBridge, _dstChid, message);
        emit Sent(msg.sender, _nft, _id, _dstChid, _receiver, _dstNft);
    }

    // burn to withdraw or mint on another chain, arg has backToOrig bool if dest chain is NFT's orig, set to true
    // sendMessage withdraw or mint
    /**
     * @notice burn deletes user's NFT in nft contract and send message to withdraw or mint on dest chain
     * @param _nft address of source NFT contract
     * @param _id nft token ID to bridge
     * @param _dstChid dest chain ID
     * @param _receiver receiver address on dest chain
     * @param _dstNft dest chain NFT address
     * @param _dstBridge dest chain NFTBridge address, so we know what address should receive msg. we could save in map and not require this?
     * @param _backToOrigin if dest chain is the original chain of this NFT, set to true
     */
    function burn(
        address _nft,
        uint256 _id,
        uint64 _dstChid,
        address _receiver,
        address _dstNft,
        address _dstBridge,
        bool _backToOrigin
    ) external payable {
        string memory _uri = INFT(_nft).tokenURI(_id);
        INFT(_nft).burn(_id);
        NFTMsg memory nftMsg = NFTMsg(MsgType.Mint, _receiver, _dstNft, _id, _uri);
        if (_backToOrigin) {
            nftMsg.msgType = MsgType.Withdraw;
        }
        bytes memory message = abi.encode(nftMsg);
        uint256 fee = IMessageBus(messageBus).calcFee(message);
        require(msg.value >= fee + destTxFee[_dstChid], "insufficient fee");
        IMessageBus(messageBus).sendMessage{value: fee}(_dstBridge, _dstChid, message);
        emit Sent(msg.sender, _nft, _id, _dstChid, _receiver, _dstNft);
    }

    // ===== called by msgbus
    function executeMessage(
        address,
        uint64 srcChid,
        bytes memory _message
    ) external payable override onlyMessageBus returns (bool) {
        // withdraw original locked nft back to user, or mint new nft depending on msg.type
        NFTMsg memory nftMsg = abi.decode((_message), (NFTMsg));
        if (nftMsg.msgType == MsgType.Mint) {
            INFT(nftMsg.nft).mint(nftMsg.user, nftMsg.id, nftMsg.uri);
        } else if (nftMsg.msgType == MsgType.Withdraw) {
            INFT(nftMsg.nft).transferFrom(address(this), nftMsg.user, nftMsg.id);
        } else {
            revert("invalid message type");
        }
        emit Received(nftMsg.user, nftMsg.nft, nftMsg.id, srcChid);
        return true;
    }

    // only owner
    // set destTxFee
    function setTxFee(uint64 chid, uint256 fee) external onlyOwner {
        destTxFee[chid] = fee;
    }

    // send all gas token this contract has to owner
    function claimFee() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
