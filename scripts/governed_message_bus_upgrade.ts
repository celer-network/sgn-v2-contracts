import { AbiCoder } from 'ethers/lib/utils';
import { deployments } from 'hardhat';

import { hex2Bytes } from '../test/lib/proto';
import { Ownable__factory, SimpleGovernance__factory } from '../typechain';
import { getDeployerSigner } from './common';

async function upgrade(): Promise<void> {
  const govDeployment = await deployments.get('SimpleGovernance');

  const adminDeployment = await deployments.get('DefaultProxyAdmin');
  console.log('DefaultProxyAdmin', adminDeployment.address);

  const msgbusProxyDeployment = await deployments.get('MessageBus_Proxy');
  console.log('MessageBus_Proxy', msgbusProxyDeployment.address);

  const implDeployment = await deployments.get('MessageBus_Implementation');
  console.log('MessageBus_Implementation', implDeployment.address);

  const deployerSigner = await getDeployerSigner();

  const proxyAdmin = await Ownable__factory.connect(adminDeployment.address, deployerSigner);

  const gov = await SimpleGovernance__factory.connect(govDeployment.address, deployerSigner);
  let data = '0x99a88ec4'; // upgrade(address,address)
  const abi = new AbiCoder();
  const params = abi.encode(['address', 'address'], [msgbusProxyDeployment.address, implDeployment.address]);
  data = data.concat(params.replace('0x', ''));

  console.log('upgrade calldata', data);

  // uncomment this if you just want to check the encoded tx calldata
  // const tx = await gov.populateTransaction['createProposal(address,bytes)'](proxyAdmin.address, hex2Bytes(data));
  // console.log('createProposal tx', tx);

  // sends the createProposal tx
  const tx = await gov['createProposal(address,bytes)'](proxyAdmin.address, hex2Bytes(data));
  console.log('createProposal tx', tx.hash);
}

upgrade();
