// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.9;

import "../framework/MessageReceiverApp.sol";
import "../interfaces/IMessageBus.sol";
import "../../safeguard/Pauser.sol";

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
    function bridgeMint(
        address to,
        uint256 id,
        string memory uri
    ) external;

    function burn(uint256 id) external;
}

/** @title NFT Bridge */
contract NFTBridge is MessageReceiverApp, Pauser {
    /// per dest chain id executor fee in this chain's gas token
    mapping(uint64 => uint256) public destTxFee;
    /// per dest chain id NFTBridge address
    mapping(uint64 => address) public destBridge;
    /// first key is NFT address on this chain, 2nd key is dest chain id, value is address on dest chain
    mapping(address => mapping(uint64 => address)) public destNFTAddr;

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

    // emit when params change
    event SetDestNFT(address srcNft, uint64 dstChid, address dstNft);
    event SetTxFee(uint64 chid, uint256 fee);
    event SetDestBridge(uint64 dstChid, address dstNftBridge);
    event FeeClaimed(uint256 amount);

    constructor(address _msgBus) {
        messageBus = _msgBus;
    }

    // only to be called by Proxy via delegatecall and will modify Proxy state
    // initOwner will fail if owner is already set, so only delegateCall will work
    function init(address _msgBus) external {
        initOwner();
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
     */
    function deposit(
        address _nft,
        uint256 _id,
        uint64 _dstChid,
        address _receiver
    ) external payable whenNotPaused {
        INFT(_nft).transferFrom(msg.sender, address(this), _id);
        require(INFT(_nft).ownerOf(_id) == address(this), "transfer NFT failed");
        (address _dstBridge, address _dstNft) = checkAddr(_nft, _dstChid);
        msgBus(
            _dstBridge,
            _dstChid,
            abi.encode(NFTMsg(MsgType.Mint, _receiver, _dstNft, _id, INFT(_nft).tokenURI(_id)))
        );
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
     * @param _backToOrigin if dest chain is the original chain of this NFT, set to true
     */
    function burn(
        address _nft,
        uint256 _id,
        uint64 _dstChid,
        address _receiver,
        bool _backToOrigin
    ) external payable whenNotPaused {
        require(msg.sender == INFT(_nft).ownerOf(_id), "not token owner");
        (address _dstBridge, address _dstNft) = checkAddr(_nft, _dstChid);
        string memory _uri = INFT(_nft).tokenURI(_id);
        INFT(_nft).burn(_id);
        NFTMsg memory nftMsg = NFTMsg(MsgType.Mint, _receiver, _dstNft, _id, _uri);
        if (_backToOrigin) {
            nftMsg.msgType = MsgType.Withdraw;
        }
        msgBus(_dstBridge, _dstChid, abi.encode(nftMsg));
        emit Sent(msg.sender, _nft, _id, _dstChid, _receiver, _dstNft);
    }

    // ===== called by MCN NFT after NFT is burnt
    function sendMsg(
        uint64 _dstChid,
        address _sender,
        address _receiver,
        uint256 _id,
        string calldata _uri
    ) external payable whenNotPaused {
        address _nft = msg.sender;
        (address _dstBridge, address _dstNft) = checkAddr(_nft, _dstChid);
        msgBus(_dstBridge, _dstChid, abi.encode(NFTMsg(MsgType.Mint, _receiver, _dstNft, _id, _uri)));
        emit Sent(_sender, _nft, _id, _dstChid, _receiver, _dstNft);
    }

    // ===== called by msgbus
    function executeMessage(
        address sender,
        uint64 srcChid,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus whenNotPaused returns (ExecutionStatus) {
        require(sender == destBridge[srcChid], "nft bridge addr mismatch");
        // withdraw original locked nft back to user, or mint new nft depending on msg.type
        NFTMsg memory nftMsg = abi.decode((_message), (NFTMsg));
        // or we could try to see if ownerOf(id) is self, but openzep erc721 impl require id is valid
        if (nftMsg.msgType == MsgType.Mint) {
            INFT(nftMsg.nft).bridgeMint(nftMsg.user, nftMsg.id, nftMsg.uri);
        } else if (nftMsg.msgType == MsgType.Withdraw) {
            INFT(nftMsg.nft).transferFrom(address(this), nftMsg.user, nftMsg.id);
        } else {
            revert("invalid message type");
        }
        emit Received(nftMsg.user, nftMsg.nft, nftMsg.id, srcChid);
        return ExecutionStatus.Success;
    }

    // ===== internal utils
    // check _nft and destChid are valid, return dstBridge and dstNft
    function checkAddr(address _nft, uint64 _dstChid) internal view returns (address dstBridge, address dstNft) {
        dstBridge = destBridge[_dstChid];
        require(dstBridge != address(0), "dest NFT Bridge not found");
        dstNft = destNFTAddr[_nft][_dstChid];
        require(dstNft != address(0), "dest NFT not found");
    }

    // check fee and call msgbus sendMessage
    function msgBus(
        address _dstBridge,
        uint64 _dstChid,
        bytes memory message
    ) internal {
        uint256 fee = IMessageBus(messageBus).calcFee(message);
        require(msg.value >= fee + destTxFee[_dstChid], "insufficient fee");
        IMessageBus(messageBus).sendMessage{value: fee}(_dstBridge, _dstChid, message);
    }

    // only owner
    // set per NFT, per chain id, address
    function setDestNFT(
        address srcNft,
        uint64 dstChid,
        address dstNft
    ) external onlyOwner {
        destNFTAddr[srcNft][dstChid] = dstNft;
        emit SetDestNFT(srcNft, dstChid, dstNft);
    }

    // set all dest chains
    function setDestNFTs(
        address srcNft,
        uint64[] calldata dstChid,
        address[] calldata dstNft
    ) external onlyOwner {
        require(dstChid.length == dstNft.length, "length mismatch");
        for (uint256 i = 0; i < dstChid.length; i++) {
            destNFTAddr[srcNft][dstChid[i]] = dstNft[i];
        }
    }

    // set destTxFee
    function setTxFee(uint64 chid, uint256 fee) external onlyOwner {
        destTxFee[chid] = fee;
        emit SetTxFee(chid, fee);
    }

    // set per chain id, nft bridge address
    function setDestBridge(uint64 dstChid, address dstNftBridge) external onlyOwner {
        destBridge[dstChid] = dstNftBridge;
        emit SetDestBridge(dstChid, dstNftBridge);
    }

    // batch set nft bridge addresses for multiple chainids
    function setDestBridges(uint64[] calldata dstChid, address[] calldata dstNftBridge) external onlyOwner {
        for (uint256 i = 0; i < dstChid.length; i++) {
            destBridge[dstChid[i]] = dstNftBridge[i];
        }
    }

    // send all gas token this contract has to owner
    function claimFee() external onlyOwner {
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
        emit FeeClaimed(amount);
    }
}
