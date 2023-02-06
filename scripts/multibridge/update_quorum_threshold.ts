import * as dotenv from 'dotenv';
import "hardhat-change-network";
import "hardhat-deploy";
import hre from 'hardhat';

import { MockCaller__factory } from '../../typechain/factories/MockCaller__factory';
import { MultiBridgeSender__factory } from '../../typechain/factories/MultiBridgeSender__factory';
import { MultiBridgeReceiver__factory } from '../../typechain/factories/MultiBridgeReceiver__factory';
import { getDeployerSigner, getFeeOverrides, waitTx } from '../common';
import {PayableOverrides} from "ethers/lib/ethers";

dotenv.config();

const mockCallerAddr = process.env.MULTI_BRIDGE_MOCK_CALLER as string;
const multiBridgeSenderAddr = process.env.MULTI_BRIDGE_SENDER as string;
const multiBridgeReceiverAddr = process.env.MULTI_BRIDGE_RECEIVER as string;
const srcChain = process.env.MULTI_BRIDGE_SRC_CHAIN as string;
const dstChain = process.env.MULTI_BRIDGE_DST_CHAIN as string;
const quorumThreshold = process.env.MULTI_BRIDGE_QUORUM_THRESHOLD as string;


async function updateQuorunThreshold(): Promise<void> {
  if (!mockCallerAddr || !multiBridgeSenderAddr || !multiBridgeReceiverAddr || !srcChain || !dstChain) {
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

  // update quorumThreshold of MultiBridgeReceiver
  console.log("remote call to multiBridgeReceiver for updating quorum threshold");
  const callData = multiBridgeReceiver.interface.encodeFunctionData("updateQuorumThreshold", [quorumThreshold]);
  const messageTotalFee = await multiBridgeSender.estimateTotalMessageFee(dstChainId, multiBridgeSenderAddr, callData);
  let srcPayableOverrides = <PayableOverrides>srcFeeOverrides;
  srcPayableOverrides.value = messageTotalFee;
  const tx = await mockCaller.remoteCall(dstChainId,
      multiBridgeReceiverAddr,
      callData,
      srcPayableOverrides);
  await waitTx(tx);
}

updateQuorunThreshold();
