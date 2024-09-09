import 'hardhat-deploy';

import * as dotenv from 'dotenv';

import { getDeployerSigner, } from './common';

dotenv.config();

async function sendTxWithData(): Promise<void> {
    const deployerSigner = await getDeployerSigner();

    const tx_to = process.env.TX_TO || '';
    const tx_data = process.env.TX_DATA as string;

    const txReceipt = await deployerSigner.sendTransaction({ data: tx_data, to: tx_to });
    await txReceipt.wait();
}

sendTxWithData();
