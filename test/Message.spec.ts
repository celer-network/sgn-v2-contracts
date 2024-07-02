import { expect } from 'chai';
import {
  AbiCoder,
  AbstractSigner,
  getBytes,
  parseUnits,
  solidityPacked,
  solidityPackedKeccak256,
  toNumber
} from 'ethers';
import { ethers } from 'hardhat';

import { HardhatEthersSigner, SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Bridge, MessageBus, MsgTest, TestERC20 } from '../typechain';
import { deployMessageContracts } from './lib/common';
import * as consts from './lib/constants';
import { calculateSignatures, getRelayRequest } from './lib/proto';

type RouteInfoStruct = {
  sender: string;
  receiver: string;
  srcChainId: number;
  srcTxHash: string;
};

type RouteInfo2Struct = {
  sender: Uint8Array;
  receiver: string;
  srcChainId: number;
  srcTxHash: string;
};

const abiCoder = AbiCoder.defaultAbiCoder();

async function computeMessageIdAndSigs(
  chainId: number,
  msgbus: string,
  route: RouteInfoStruct,
  message: string,
  signers: AbstractSigner[]
) {
  const messageId = solidityPackedKeccak256(
    ['uint8', 'address', 'address', 'uint64', 'bytes32', 'uint64', 'bytes'],
    [consts.TYPE_MSG_ONLY, route.sender, route.receiver, route.srcChainId, route.srcTxHash, chainId, message]
  );
  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, msgbus, 'Message']);
  const signedData = solidityPacked(['bytes32', 'bytes32'], [domain, messageId]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));
  return { messageId, sigs };
}

async function computeMessage2IdAndSigs(
  chainId: number,
  msgbus: string,
  route: RouteInfo2Struct,
  message: string,
  signers: AbstractSigner[]
) {
  const messageId = solidityPackedKeccak256(
    ['uint8', 'bytes', 'address', 'uint64', 'bytes32', 'uint64', 'bytes'],
    [consts.TYPE_MSG_ONLY, route.sender, route.receiver, route.srcChainId, route.srcTxHash, chainId, message]
  );
  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, msgbus, 'Message2']);
  const signedData = solidityPacked(['bytes32', 'bytes32'], [domain, messageId]);
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures(signers, getBytes(signedDataHash));
  return { messageId, sigs };
}

async function getMessageWithTransferRequest(
  chainId: number,
  msgbus: string,
  bridge: string,
  sender: string,
  receiver: string,
  token: string,
  amount: bigint,
  srcChainId: number,
  refId: string,
  srcTxHash: string,
  message: string,
  signer: SignerWithAddress,
  power: bigint
) {
  const relayReq = await getRelayRequest(
    sender,
    receiver,
    token,
    amount,
    srcChainId,
    chainId,
    refId, // fake src transfer Id
    [signer],
    bridge
  );
  const bridgeTransferParams = {
    request: relayReq.relayBytes,
    sigs: relayReq.sigs,
    signers: [signer.address],
    powers: [power]
  };

  const xferId = solidityPackedKeccak256(
    ['address', 'address', 'address', 'uint256', 'uint64', 'uint64', 'bytes32'],
    [sender, receiver, token, amount, srcChainId, chainId, refId]
  );
  const messageId = solidityPackedKeccak256(['uint8', 'address', 'bytes32'], [consts.TYPE_MSG_XFER, bridge, xferId]);
  const domain = solidityPackedKeccak256(['uint256', 'address', 'string'], [chainId, msgbus, 'MessageWithTransfer']);
  const signedData = solidityPacked(
    ['bytes32', 'bytes32', 'bytes', 'bytes32'],
    [domain, messageId, message, srcTxHash]
  );
  const signedDataHash = solidityPackedKeccak256(['bytes'], [signedData]);
  const sigs = await calculateSignatures([signer], getBytes(signedDataHash));

  const transferInfo = {
    t: consts.XFER_TYPE_LQ_RELAY,
    sender: sender,
    receiver: receiver,
    token: token,
    amount: amount,
    wdseq: 0,
    srcChainId: srcChainId,
    refId: refId,
    srcTxHash: srcTxHash
  };

  const executionParams = {
    message: message,
    transfer: transferInfo,
    sigs: sigs,
    signers: [signer.address],
    powers: [power]
  };

  return { bridgeTransferParams, executionParams, messageId };
}

describe('Message Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { bridge, msgBus, msgTest, token } = await deployMessageContracts(admin);
    await bridge.resetSigners([admin.address], [parseUnits('1')]);
    return { admin, bridge, msgBus, msgTest, token };
  }

  let admin: HardhatEthersSigner;
  let bridge: Bridge;
  let msgBus: MessageBus;
  let msgTest: MsgTest;
  let token: TestERC20;
  let chainId: number;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    admin = res.admin;
    bridge = res.bridge;
    token = res.token;
    msgBus = res.msgBus;
    msgTest = res.msgTest;
    chainId = toNumber((await ethers.provider.getNetwork()).chainId);
  });

  it('should execute msg correctly', async function () {
    const hash = solidityPackedKeccak256(['string'], ['hello']);
    const srcChainId = 5;
    const routeInfo = {
      sender: admin.address,
      receiver: await msgTest.getAddress(),
      srcChainId: srcChainId,
      srcTxHash: hash // fake tx hash
    };
    let nonce = 1;
    let message = abiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    let res = await computeMessageIdAndSigs(chainId, await msgBus.getAddress(), routeInfo, message, [admin]);
    await expect(
      msgBus.getFunction('executeMessage(bytes,(address,address,uint64,bytes32),bytes[],address[],uint256[])')(
        message,
        routeInfo,
        res.sigs,
        [admin.address],
        [parseUnits('1')]
      )
    )
      .to.emit(msgTest, 'MessageReceived')
      .withArgs(admin.address, srcChainId, nonce, hash)
      .to.emit(msgBus, 'Executed')
      .withArgs(
        consts.TYPE_MSG_ONLY,
        res.messageId,
        consts.MSG_TX_SUCCESS,
        await msgTest.getAddress(),
        srcChainId,
        hash
      );

    const routeInfo2 = {
      sender: getBytes(admin.address),
      receiver: await msgTest.getAddress(),
      srcChainId: srcChainId,
      srcTxHash: hash // fake tx hash
    };
    nonce = 2;
    message = abiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessage2IdAndSigs(chainId, await msgBus.getAddress(), routeInfo2, message, [admin]);
    await expect(
      msgBus.getFunction('executeMessage(bytes,(bytes,address,uint64,bytes32),bytes[],address[],uint256[])')(
        message,
        routeInfo2,
        res.sigs,
        [admin.address],
        [parseUnits('1')]
      )
    )
      .to.emit(msgTest, 'Message2Received')
      .withArgs(solidityPacked(['address'], [admin.address]), srcChainId, nonce, hash)
      .to.emit(msgBus, 'Executed')
      .withArgs(
        consts.TYPE_MSG_ONLY,
        res.messageId,
        consts.MSG_TX_SUCCESS,
        await msgTest.getAddress(),
        srcChainId,
        hash
      );

    nonce = 100000000000001;
    message = abiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessageIdAndSigs(chainId, await msgBus.getAddress(), routeInfo, message, [admin]);
    await expect(
      msgBus.getFunction('executeMessage(bytes,(address,address,uint64,bytes32),bytes[],address[],uint256[])')(
        message,
        routeInfo,
        res.sigs,
        [admin.address],
        [parseUnits('1')]
      )
    )
      .to.emit(msgBus, 'CallReverted')
      .withArgs('invalid nonce')
      .to.emit(msgBus, 'Executed')
      .withArgs(consts.TYPE_MSG_ONLY, res.messageId, consts.MSG_TX_FAIL, await msgTest.getAddress(), srcChainId, hash);

    nonce = 100000000000002;
    message = abiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessageIdAndSigs(chainId, await msgBus.getAddress(), routeInfo, message, [admin]);
    await expect(
      msgBus.getFunction('executeMessage(bytes,(address,address,uint64,bytes32),bytes[],address[],uint256[])')(
        message,
        routeInfo,
        res.sigs,
        [admin.address],
        [parseUnits('1')]
      )
    )
      .to.emit(msgBus, 'CallReverted')
      .withArgs('Transaction reverted silently')
      .to.emit(msgBus, 'Executed')
      .withArgs(consts.TYPE_MSG_ONLY, res.messageId, consts.MSG_TX_FAIL, await msgTest.getAddress(), srcChainId, hash);

    nonce = 100000000000004;
    message = abiCoder.encode(['uint64', 'bytes'], [nonce, hash]);
    res = await computeMessageIdAndSigs(chainId, await msgBus.getAddress(), routeInfo, message, [admin]);
    await expect(
      msgBus.getFunction('executeMessage(bytes,(address,address,uint64,bytes32),bytes[],address[],uint256[])')(
        message,
        routeInfo,
        res.sigs,
        [admin.address],
        [parseUnits('1')]
      )
    ).to.be.revertedWith('MSG::ABORT:invalid nonce');
  });

  it('should execute msg with transfer correctly', async function () {
    await token.approve(bridge.getAddress(), parseUnits('100'));
    await bridge.addLiquidity(token.getAddress(), parseUnits('50'));
    const hash = solidityPackedKeccak256(['string'], ['hello']);
    const amount = parseUnits('1');
    const srcChainId = 5;
    const message = abiCoder.encode(['address', 'bytes'], [admin.address, hash]);
    const res = await getMessageWithTransferRequest(
      chainId,
      await msgBus.getAddress(),
      await bridge.getAddress(),
      admin.address,
      await msgTest.getAddress(),
      await token.getAddress(),
      amount,
      srcChainId,
      hash, // fake src transfer Id
      hash, // fake src srcTxHash
      message,
      admin,
      parseUnits('1')
    );
    await expect(msgBus.transferAndExecuteMsg(res.bridgeTransferParams, res.executionParams))
      .to.emit(msgBus, 'Executed')
      .withArgs(
        consts.TYPE_MSG_XFER,
        res.messageId,
        consts.MSG_TX_SUCCESS,
        await msgTest.getAddress(),
        srcChainId,
        hash
      )
      .to.emit(msgTest, 'MessageReceivedWithTransfer')
      .withArgs(await token.getAddress(), amount, admin.address, srcChainId, admin.address, hash);

    await expect(
      msgBus.executeMessageWithTransfer(
        message,
        res.executionParams.transfer,
        res.executionParams.sigs,
        res.executionParams.signers,
        res.executionParams.powers
      )
    ).to.be.revertedWith('transfer already executed');
  });
});
