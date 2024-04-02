import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { MessageBus__factory } from '../typechain';
import { getDeployerSigner } from './common';

dotenv.config();

async function query(): Promise<void> {
  const deployerSigner = await getDeployerSigner();

  const msgbus = MessageBus__factory.connect("0x9Bb46D5100d2Db4608112026951c9C965b233f4D", deployerSigner);
  const vault = await msgbus.pegVault() 
  const bridge = await msgbus.pegBridge() 
  const vault2 = await msgbus.pegVaultV2() 
  const bridge2 = await msgbus.pegBridgeV2() 

  console.log(`vault ${vault}, vault2 ${vault2}, bridge ${bridge}, bridge2 ${bridge2}`);
}

query();
