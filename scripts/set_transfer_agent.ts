import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { Ownable__factory } from '../typechain/factories/Ownable__factory';
import { getDeployerSigner, getFeeOverrides } from './common';
import {TransferAgent__factory} from "../typechain";

dotenv.config();

async function setTransferAgent(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const feeOverrides = await getFeeOverrides();

  const contractAddr = process.env.TRANSFER_AGENT_ADDRESS as string;
  if (!contractAddr) {
    return;
  }
  const sendType = (process.env.TRANSFER_AGENT_SEND_TYPE as string).split(',');
  const bridgeAddr = (process.env.TRANSFER_AGENT_BRIDGE_ADDR as string).split(',');
  const contract = TransferAgent__factory.connect(contractAddr, deployerSigner);
  if (bridgeAddr[0].length > 0) {
    for (let i = 0; i < sendType.length; i++) {
      await (await contract.setBridgeAddress(sendType[i], bridgeAddr[i])).wait();
      console.log('setBridgeAddress', bridgeAddr[i]);
    }
  }
}

setTransferAgent();
