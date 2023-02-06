import * as dotenv from 'dotenv';
import "hardhat-change-network";
import "hardhat-deploy";
import hre from 'hardhat';

import { MockCaller__factory } from '../../typechain/factories/MockCaller__factory';
import { MultiBridgeSender__factory } from '../../typechain/factories/MultiBridgeSender__factory';
import { MultiBridgeReceiver__factory } from '../../typechain/factories/MultiBridgeReceiver__factory';
import { getDeployerSigner, getFeeOverrides } from '../common';
import {Bridge__factory, IBridgeSenderAdapter, IBridgeSenderAdapter__factory} from "../../typechain";
import {IBridgeReceiverAdapter, IBridgeReceiverAdapter__factory} from "../../typechain";

dotenv.config();

const mockCallerAddr = process.env.MULTI_BRIDGE_MOCK_CALLER as string;
const grantedCallerAddr = process.env.MULTI_BRIDGE_GRANTED_CALLER as string;
const multiBridgeSenderAddr = process.env.MULTI_BRIDGE_SENDER as string;
const multiBridgeReceiverAddr = process.env.MULTI_BRIDGE_RECEIVER as string;
const srcChain = process.env.MULTI_BRIDGE_SRC_CHAIN as string;
const dstChain = process.env.MULTI_BRIDGE_DST_CHAIN as string;
const senderAdaptersAddr = (process.env.MULTI_BRIDGE_SENDER_ADAPTERS as string).split(',');
const receiverAdaptersAddr = (process.env.MULTI_BRIDGE_RECEIVER_ADAPTERS as string).split(',');
const receiverPowers = (process.env.MULTI_BRIDGE_RECEIVER_POWERS as string).split(',');
const quorumThreshold = process.env.MULTI_BRIDGE_QUORUM_THRESHOLD as string;

async function initializeMultibridge(): Promise<void> {
  if (!mockCallerAddr || !multiBridgeSenderAddr || !multiBridgeReceiverAddr || !srcChain || !dstChain) {
    return;
  }
  if (senderAdaptersAddr.length == 0 || senderAdaptersAddr.length != receiverAdaptersAddr.length) {
    console.error("no adapter or mismatch length of adapters")
    return;
  }

  // construct contract instances on src chain
  hre.changeNetwork(srcChain);
  const srcDeployerSigner = await getDeployerSigner();
  const srcChainId = await srcDeployerSigner.getChainId();
  const srcFeeOverrides = await getFeeOverrides();
  const multiBridgeSender = MultiBridgeSender__factory.connect(multiBridgeSenderAddr, srcDeployerSigner);
  let senderAdapters: IBridgeSenderAdapter[] = new Array(senderAdaptersAddr.length);
  for (let i = 0; i < senderAdaptersAddr.length; i++) {
    senderAdapters[i] = IBridgeSenderAdapter__factory.connect(senderAdaptersAddr[i], srcDeployerSigner);
  }
  const mockCaller = MockCaller__factory.connect(mockCallerAddr, srcDeployerSigner);

  // construct contract instances on dst chain
  hre.changeNetwork(dstChain);
  const dstDeployerSigner = await getDeployerSigner();
  const dstChainId = await dstDeployerSigner.getChainId();
  const dstFeeOverrides = await getFeeOverrides();
  const multiBridgeReceiver = MultiBridgeReceiver__factory.connect(multiBridgeReceiverAddr, dstDeployerSigner);
  let receiverAdapters: IBridgeReceiverAdapter[] = new Array(receiverAdaptersAddr.length);
  for (let i = 0; i < receiverAdaptersAddr.length; i++) {
    receiverAdapters[i] = IBridgeReceiverAdapter__factory.connect(receiverAdaptersAddr[i], dstDeployerSigner);
  }

  // setup contracts on src chain
  console.log("setMultiBridgeSender in mock caller: ", multiBridgeSender.address);
  let tx = await mockCaller.setMultiBridgeSender(multiBridgeSender.address, srcFeeOverrides);
  await waitTx(tx);

  for (let i = 0; i < senderAdaptersAddr.length; i++) {
    console.log("setMultiBridgeSender", senderAdaptersAddr[i], multiBridgeSenderAddr);
    tx = await senderAdapters[i].setMultiBridgeSender(multiBridgeSenderAddr, srcFeeOverrides);
    await waitTx(tx);
    console.log("updateReceiverAdapter", senderAdaptersAddr[i], dstChainId, receiverAdaptersAddr[i]);
    tx = await senderAdapters[i].updateReceiverAdapter([dstChainId], [receiverAdaptersAddr[i]], srcFeeOverrides);
    await waitTx(tx);
  }

  console.log("addSenderAdapters: ", senderAdaptersAddr);
  tx = await mockCaller.addSenderAdapters(senderAdaptersAddr, srcFeeOverrides);
  await waitTx(tx);

  // setup contracts on dst chain
  for (let i = 0; i < receiverAdaptersAddr.length; i++) {
    console.log("setMultiBridgeReceiver", receiverAdaptersAddr[i], multiBridgeReceiverAddr);
    tx = await receiverAdapters[i].setMultiBridgeReceiver(multiBridgeReceiverAddr, dstFeeOverrides);
    await waitTx(tx);
    console.log("updateSenderAdapter", receiverAdaptersAddr[i], srcChainId, senderAdaptersAddr[i]);
    tx = await receiverAdapters[i].updateSenderAdapter([srcChainId], [senderAdaptersAddr[i]], dstFeeOverrides);
    await waitTx(tx);
  }

  console.log("multiBridgeReceiver initialize", multiBridgeReceiverAddr);
  tx = await multiBridgeReceiver.initialize(
    receiverAdaptersAddr, //address[] memory _receiverAdapters,
    receiverPowers, //uint32[] memory _powers,
    quorumThreshold); //uint64 _quorumThreshold
  await waitTx(tx);
}

async function grantCallerRole(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  if (!mockCallerAddr || !grantedCallerAddr) {
    return;
  }
  const mockCaller = MockCaller__factory.connect(mockCallerAddr, deployerSigner);
  console.log("grantRole CALLER_ROLE: ", grantedCallerAddr);
  const CALLER_ROLE = await mockCaller.CALLER_ROLE();
  let tx = await mockCaller.grantRole(CALLER_ROLE, grantedCallerAddr, feeOverrides);
  await waitTx(tx);
}

async function waitTx(tx: any) {
  const blockConfirmations = 1;
  console.log(`Waiting ${blockConfirmations} block confirmations for tx ${tx.hash} ...`);
  const receipt = await tx.wait(blockConfirmations);
  // console.log(receipt);
}

// grantCallerRole();
initializeMultibridge();
