// SPDX-License-Identifier: GPL-3.0-only

// Code generated by protoc-gen-sol. DO NOT EDIT.
// source: contracts/libraries/proto/staking.proto
pragma solidity >=0.5.0;
import "./Pb.sol";

library PbStaking {
    using Pb for Pb.Buffer; // so we can call Pb funcs on Buffer obj

    struct Reward {
        address recipient; // tag: 1
        uint256 cumulativeReward; // tag: 2
    } // end struct Reward

    function decReward(bytes memory raw) internal pure returns (Reward memory m) {
        Pb.Buffer memory buf = Pb.fromBytes(raw);

        uint256 tag;
        Pb.WireType wire;
        while (buf.hasMore()) {
            (tag, wire) = buf.decKey();
            if (false) {}
            // solidity has no switch/case
            else if (tag == 1) {
                m.recipient = Pb._address(buf.decBytes());
            } else if (tag == 2) {
                m.cumulativeReward = Pb._uint256(buf.decBytes());
            } else {
                buf.skipValue(wire);
            } // skip value of unknown tag
        }
    } // end decoder Reward

    struct Slash {
        address validator; // tag: 1
        uint64 nonce; // tag: 2
        uint64 slashFactor; // tag: 3
        uint64 expireBlock; // tag: 4
        bool unbond; // tag: 5
        AcctAmtPair[] collectors; // tag: 6
    } // end struct Slash

    function decSlash(bytes memory raw) internal pure returns (Slash memory m) {
        Pb.Buffer memory buf = Pb.fromBytes(raw);

        uint256[] memory cnts = buf.cntTags(6);
        m.collectors = new AcctAmtPair[](cnts[6]);
        cnts[6] = 0; // reset counter for later use

        uint256 tag;
        Pb.WireType wire;
        while (buf.hasMore()) {
            (tag, wire) = buf.decKey();
            if (false) {}
            // solidity has no switch/case
            else if (tag == 1) {
                m.validator = Pb._address(buf.decBytes());
            } else if (tag == 2) {
                m.nonce = uint64(buf.decVarint());
            } else if (tag == 3) {
                m.slashFactor = uint64(buf.decVarint());
            } else if (tag == 4) {
                m.expireBlock = uint64(buf.decVarint());
            } else if (tag == 5) {
                m.unbond = Pb._bool(buf.decVarint());
            } else if (tag == 6) {
                m.collectors[cnts[6]] = decAcctAmtPair(buf.decBytes());
                cnts[6]++;
            } else {
                buf.skipValue(wire);
            } // skip value of unknown tag
        }
    } // end decoder Slash

    struct AcctAmtPair {
        address account; // tag: 1
        uint256 amount; // tag: 2
    } // end struct AcctAmtPair

    function decAcctAmtPair(bytes memory raw) internal pure returns (AcctAmtPair memory m) {
        Pb.Buffer memory buf = Pb.fromBytes(raw);

        uint256 tag;
        Pb.WireType wire;
        while (buf.hasMore()) {
            (tag, wire) = buf.decKey();
            if (false) {}
            // solidity has no switch/case
            else if (tag == 1) {
                m.account = Pb._address(buf.decBytes());
            } else if (tag == 2) {
                m.amount = Pb._uint256(buf.decBytes());
            } else {
                buf.skipValue(wire);
            } // skip value of unknown tag
        }
    } // end decoder AcctAmtPair
}
