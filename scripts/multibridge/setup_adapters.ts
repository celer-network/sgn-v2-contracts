import * as dotenv from 'dotenv';
import "hardhat-change-network";
import "hardhat-deploy";
import hre from 'hardhat';

import { getDeployerSigner, getFeeOverrides, waitTx } from '../common';
import {IBridgeSenderAdapter, IBridgeSenderAdapter__factory} from "../../typechain";
import {IBridgeReceiverAdapter, IBridgeReceiverAdapter__factory} from "../../typechain";
import {ContractTransaction} from "@ethersproject/contracts";

dotenv.config();

const multiBridgeSenderAddr = process.env.MULTI_BRIDGE_SENDER as string;
const multiBridgeReceiverAddr = process.env.MULTI_BRIDGE_RECEIVER as string;
const srcChain = process.env.MULTI_BRIDGE_SRC_CHAIN as string;
const dstChain = process.env.MULTI_BRIDGE_DST_CHAIN as string;
const senderAdaptersAddr = (process.env.MULTI_BRIDGE_SENDER_ADAPTERS as string).split(',');
const receiverAdaptersAddr = (process.env.MULTI_BRIDGE_RECEIVER_ADAPTERS as string).split(',');

async function setupAdapters(): Promise<void> {
  if (!srcChain || !dstChain) {
    return;
  }
  if (senderAdaptersAddr.length == 0 ||
      senderAdaptersAddr.length != receiverAdaptersAddr.length) {
    console.error("no adapter or mismatch length of adapters")
    return;
  }

  // construct contract instances on src chain
  hre.changeNetwork(srcChain);
  const srcDeployerSigner = await getDeployerSigner();
  const srcChainId = await srcDeployerSigner.getChainId();
  const srcFeeOverrides = await getFeeOverrides();
  let senderAdapters: IBridgeSenderAdapter[] = new Array(senderAdaptersAddr.length);
  for (let i = 0; i < senderAdaptersAddr.length; i++) {
    senderAdapters[i] = IBridgeSenderAdapter__factory.connect(senderAdaptersAddr[i], srcDeployerSigner);
  }

  // construct contract instances on dst chain
  hre.changeNetwork(dstChain);
  const dstDeployerSigner = await getDeployerSigner();
  const dstChainId = await dstDeployerSigner.getChainId();
  const dstFeeOverrides = await getFeeOverrides();
  let receiverAdapters: IBridgeReceiverAdapter[] = new Array(receiverAdaptersAddr.length);
  for (let i = 0; i < receiverAdaptersAddr.length; i++) {
    receiverAdapters[i] = IBridgeReceiverAdapter__factory.connect(receiverAdaptersAddr[i], dstDeployerSigner);
  }

  // setup sender adapters on src chain
  let tx:ContractTransaction;
  for (let i = 0; i < senderAdaptersAddr.length; i++) {
    console.log("setMultiBridgeSender", senderAdaptersAddr[i], multiBridgeSenderAddr);
    tx = await senderAdapters[i].setMultiBridgeSender(multiBridgeSenderAddr, srcFeeOverrides);
    await waitTx(tx);
    console.log("updateReceiverAdapter", senderAdaptersAddr[i], dstChainId, receiverAdaptersAddr[i]);
    tx = await senderAdapters[i].updateReceiverAdapter([dstChainId], [receiverAdaptersAddr[i]], srcFeeOverrides);
    await waitTx(tx);
  }

  // setup receiver adapters on dst chain
  for (let i = 0; i < receiverAdaptersAddr.length; i++) {
    console.log("setMultiBridgeReceiver", receiverAdaptersAddr[i], multiBridgeReceiverAddr);
    tx = await receiverAdapters[i].setMultiBridgeReceiver(multiBridgeReceiverAddr, dstFeeOverrides);
    await waitTx(tx);
    console.log("updateSenderAdapter", receiverAdaptersAddr[i], srcChainId, senderAdaptersAddr[i]);
    tx = await receiverAdapters[i].updateSenderAdapter([srcChainId], [senderAdaptersAddr[i]], dstFeeOverrides);
    await waitTx(tx);
  }
}

setupAdapters();
