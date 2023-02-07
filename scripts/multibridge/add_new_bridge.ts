import * as dotenv from 'dotenv';
import "hardhat-change-network";
import "hardhat-deploy";
import hre from 'hardhat';

import { MockCaller__factory } from '../../typechain/factories/MockCaller__factory';
import { MultiBridgeSender__factory } from '../../typechain/factories/MultiBridgeSender__factory';
import { MultiBridgeReceiver__factory } from '../../typechain/factories/MultiBridgeReceiver__factory';
import { getDeployerSigner, getFeeOverrides, waitTx } from '../common';
import {ContractTransaction} from "@ethersproject/contracts";
import {PayableOverrides} from "ethers/lib/ethers";

dotenv.config();

const mockCallerAddr = process.env.MULTI_BRIDGE_MOCK_CALLER as string;
const multiBridgeSenderAddr = process.env.MULTI_BRIDGE_SENDER as string;
const multiBridgeReceiverAddr = process.env.MULTI_BRIDGE_RECEIVER as string;
const srcChain = process.env.MULTI_BRIDGE_SRC_CHAIN as string;
const dstChain = process.env.MULTI_BRIDGE_DST_CHAIN as string;
const senderAdaptersAddr = (process.env.MULTI_BRIDGE_SENDER_ADAPTERS as string).split(',');
const receiverAdaptersAddr = (process.env.MULTI_BRIDGE_RECEIVER_ADAPTERS as string).split(',');
const receiverPowers = (process.env.MULTI_BRIDGE_RECEIVER_POWERS as string).split(',');

async function addNewBridge(): Promise<void> {
  if (!mockCallerAddr || !multiBridgeSenderAddr || !multiBridgeReceiverAddr || !srcChain || !dstChain) {
    return;
  }
  if (senderAdaptersAddr.length == 0 ||
      senderAdaptersAddr.length != receiverAdaptersAddr.length ||
      senderAdaptersAddr.length != receiverPowers.length) {
    console.error("no adapter or mismatch length of adapters")
    return;
  }

  // construct contract instances on src chain
  hre.changeNetwork(srcChain);
  const srcDeployerSigner = await getDeployerSigner();
  const srcFeeOverrides = await getFeeOverrides();
  const multiBridgeSender = MultiBridgeSender__factory.connect(multiBridgeSenderAddr, srcDeployerSigner);
  const mockCaller = MockCaller__factory.connect(mockCallerAddr, srcDeployerSigner);

  // construct contract instances on dst chain
  hre.changeNetwork(dstChain);
  const dstDeployerSigner = await getDeployerSigner();
  const dstChainId = await dstDeployerSigner.getChainId();
  const multiBridgeReceiver = MultiBridgeReceiver__factory.connect(multiBridgeReceiverAddr, dstDeployerSigner);

  // setup MultiBridgeSender on src chain
  let tx:ContractTransaction;
  console.log("addSenderAdapters in MultiBridgeSender: ", senderAdaptersAddr);
  tx = await mockCaller.addSenderAdapters(senderAdaptersAddr, srcFeeOverrides);
  await waitTx(tx);

  // setup MultiBridgeReceiver on dst chain
  console.log("remote call to multiBridgeReceiver for updating receiver adapter");
  const callData = multiBridgeReceiver.interface.encodeFunctionData("updateReceiverAdapter", [receiverAdaptersAddr, receiverPowers]);
  const messageTotalFee = await multiBridgeSender.estimateTotalMessageFee(dstChainId, multiBridgeSenderAddr, callData);
  console.log("total fee ", messageTotalFee.toString());
  let srcPayableOverrides = <PayableOverrides>srcFeeOverrides;
  srcPayableOverrides.value = messageTotalFee;
  // in case of bad gas estimation
  srcPayableOverrides.gasLimit = 1000000;
  tx = await mockCaller.remoteCall(dstChainId,
      multiBridgeReceiverAddr,
      callData,
      srcPayableOverrides);
  await waitTx(tx);
}

addNewBridge();
