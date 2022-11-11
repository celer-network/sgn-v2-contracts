import * as dotenv from 'dotenv';

import { hex2Bytes } from '../test/lib/proto';
import { SimpleGovernance__factory } from '../typechain';
import { getDeployerSigner } from './common';
import { encodeUpgradeData, getDeploymentContext } from './governed_message_bus_upgrade_proposal';

dotenv.config();

async function execute(): Promise<void> {
  const { govDeployment, adminDeployment, msgbusProxyDeployment, implDeployment } = await getDeploymentContext();
  const deployerSigner = await getDeployerSigner();
  const gov = await SimpleGovernance__factory.connect(govDeployment.address, deployerSigner);

  const data = encodeUpgradeData(msgbusProxyDeployment.address, implDeployment.address);

  const proposalId = process.env.GOV_MSGBUS_UPGRADE_PROPOSAL_ID;
  if (!proposalId) {
    console.error('GOV_MSGBUS_UPGRADE_PROPOSAL_ID undefined');
    return;
  }
  const tx = await gov.executeProposal(proposalId, 0, adminDeployment.address, hex2Bytes(data));

  console.log('proposal execution tx', tx.hash);
}

execute();
