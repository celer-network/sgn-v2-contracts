import * as dotenv from 'dotenv';
import { AbiCoder } from 'ethers/lib/utils';

dotenv.config();

function encodeUpgradeData(proxyAddr: string, implAddr: string): string {
  let data = '0x99a88ec4'; // upgrade(address,address)
  const abi = new AbiCoder();
  const params = abi.encode(['address', 'address'], [proxyAddr, implAddr]);
  data = data.concat(params.replace('0x', ''));
  return data;
}

const msgbusProxy = process.env.MESSAGE_BUS_PROXY;
const msgbusImpl = process.env.MESSAGE_BUS_IMPL;

if (!msgbusProxy) {
  console.error('MESSAGE_BUS_PROXY (message bus proxy address) is not configured in .env');
  process.exit(1);
}

if (!msgbusImpl) {
  console.error('MESSAGE_BUS_IMPL (message bus implementation address) is not configured in .env');
  process.exit(1);
}

const data = encodeUpgradeData(msgbusProxy, msgbusImpl);
console.log('upgrade(address,address):', data);
