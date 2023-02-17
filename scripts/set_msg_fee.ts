import 'hardhat-deploy';

import * as dotenv from 'dotenv';
import { deployments } from 'hardhat';

import { MessageBus__factory } from '../typechain/factories/MessageBus__factory';
import { getDeployerSigner } from './common';

dotenv.config();

async function setMsgFees(): Promise<void> {
  const deployerSigner = await getDeployerSigner();
  const dep = await deployments.get('MessageBus_Proxy');
  console.log('msgbus', dep.address);
  const msgbus = MessageBus__factory.connect(dep.address, deployerSigner);
  const owner = await msgbus.owner();
  const bridge = await msgbus.liquidityBridge();
  console.log('owner', owner);
  console.log('bridge', bridge);
  const tx0 = await msgbus.setFeeBase('1400000000000000');
  tx0.wait(1);
  const tx1 = await msgbus.setFeePerByte('14000000000000');
  tx1.wait(10);

  const feeBase = await msgbus.feeBase();
  const feePerByte = await msgbus.feePerByte();

  console.log(`new feeBase ${feeBase} feePerByte ${feePerByte}`);
}

setMsgFees();
