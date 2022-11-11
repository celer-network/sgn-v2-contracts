import { AbiCoder } from 'ethers/lib/utils';
import { deployments } from 'hardhat';

import { hex2Bytes } from '../test/lib/proto';
import { Ownable__factory, SimpleGovernance__factory } from '../typechain';
import { getDeployerSigner } from './common';

export function encodeUpgradeData(proxyAddr: string, implAddr: string): string {
  let data = '0x99a88ec4'; // upgrade(address,address)
  const abi = new AbiCoder();
  const params = abi.encode(['address', 'address'], [proxyAddr, implAddr]);
  data = data.concat(params.replace('0x', ''));
  return data;
}

export async function getDeploymentContext() {
  const govDeployment = await deployments.get('SimpleGovernance');
  console.log('SimpleGovernance', govDeployment.address);
  const adminDeployment = await deployments.get('DefaultProxyAdmin');
  console.log('DefaultProxyAdmin', adminDeployment.address);
  const msgbusProxyDeployment = await deployments.get('MessageBus_Proxy');
  console.log('MessageBus_Proxy', msgbusProxyDeployment.address);
  const implDeployment = await deployments.get('MessageBus_Implementation');
  console.log('MessageBus_Implementation', implDeployment.address);
  return { govDeployment, adminDeployment, msgbusProxyDeployment, implDeployment };
}

async function upgrade(): Promise<void> {
  const { govDeployment, adminDeployment, msgbusProxyDeployment, implDeployment } = await getDeploymentContext();
  const deployerSigner = await getDeployerSigner();
  const proxyAdmin = await Ownable__factory.connect(adminDeployment.address, deployerSigner);
  const gov = await SimpleGovernance__factory.connect(govDeployment.address, deployerSigner);

  const data = encodeUpgradeData(msgbusProxyDeployment.address, implDeployment.address);

  console.log('upgrade calldata', data);

  // uncomment this if you just want to check the encoded tx calldata
  const tx = await gov.populateTransaction['createProposal(address,bytes)'](proxyAdmin.address, hex2Bytes(data));
  console.log('createProposal tx', tx);
  return;

  // uncomment this if you want to actually submit the proposal
  // sends the createProposal tx
  // const tx = await gov['createProposal(address,bytes)'](proxyAdmin.address, hex2Bytes(data));
  // console.log('createProposal tx', tx.hash);
}

upgrade();
