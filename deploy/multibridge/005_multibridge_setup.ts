import * as dotenv from 'dotenv';
import { DeployFunction, DeploymentsExtension } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  
  const mockCallerInstance = await GetInstance("MockCaller", hre);
  const multiBridgeSenderInstance = await GetInstance("MultiBridgeSender", hre);
  const multiBridgeReceiverInstance = await GetInstance("MultiBridgeReceiver", hre);
  const deBridgeSenderAdapterInstance = await GetInstance("DeBridgeSenderAdapter", hre);
  const deBridgeReceiverAdapterInstance = await GetInstance("DeBridgeReceiverAdapter", hre);

  console.log("grantRole CALLER_ROLE: ", deployer);
  const CALLER_ROLE = await mockCallerInstance.CALLER_ROLE();
  let tx = await mockCallerInstance.grantRole(CALLER_ROLE, deployer);
  await waitTx(tx);

  console.log("mockCaller setMultiBridgeSender: ", multiBridgeSenderInstance.address);
  tx = await mockCallerInstance.setMultiBridgeSender(multiBridgeSenderInstance.address);
  await waitTx(tx);

  console.log("addSenderAdapters deBridgeSenderAdapter: ", deBridgeSenderAdapterInstance.address);
  tx = await mockCallerInstance.addSenderAdapters([deBridgeSenderAdapterInstance.address]);
  await waitTx(tx);

  console.log("multiBridgeReceiver initialize", deBridgeSenderAdapterInstance.address);
  tx = await multiBridgeReceiverInstance.initialize(
    [deBridgeReceiverAdapterInstance.address], //address[] memory _receiverAdapters,
    [100], //uint32[] memory _powers,
    70); //uint64 _quorumThreshold
  await waitTx(tx);

  const chainIds = [56,137].filter(c=>c !=hre.network.config.chainId);  
  const receiverAdapters =  Array(chainIds.length).fill(deBridgeReceiverAdapterInstance.address);
  
  //updateReceiverAdapter(uint64[] calldata _dstChainIds, address[] calldata _receiverAdapters)
  console.log("updateReceiverAdapter", chainIds, receiverAdapters);
  tx = await deBridgeSenderAdapterInstance.updateReceiverAdapter(chainIds, receiverAdapters);
  await waitTx(tx);
  //setMultiBridgeSender(address _multiBridgeSender) 
  console.log("setMultiBridgeSender", multiBridgeSenderInstance.address);
  tx = await deBridgeSenderAdapterInstance.setMultiBridgeSender(multiBridgeSenderInstance.address);
  await waitTx(tx);

  const senderAdapters =  Array(chainIds.length).fill(deBridgeSenderAdapterInstance.address);
  //updateSenderAdapter(uint256[] calldata _srcChainIds, address[] calldata _senderAdapters)
  console.log("updateSenderAdapter", chainIds, senderAdapters);
  tx = await deBridgeReceiverAdapterInstance.updateSenderAdapter(chainIds, senderAdapters);
  await waitTx(tx);
  //setMultiBridgeReceiver(address _multiBridgeReceiver)
  console.log("setMultiBridgeReceiver", multiBridgeReceiverInstance.address);
  tx = await deBridgeReceiverAdapterInstance.setMultiBridgeReceiver(multiBridgeReceiverInstance.address);
  await waitTx(tx);

  
};

async function GetInstance(contractName: string, hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  const contractAddress = (await deployments.get(contractName)).address;
  const factory = await hre.ethers.getContractFactory(contractName, deployer);
  return await factory.attach(contractAddress);
}

async function waitTx(tx: any) {
  const blockConfirmations = 1;
  console.log(`Waiting ${blockConfirmations} block confirmations for tx ${tx.hash} ...`);
  const receipt = await tx.wait(blockConfirmations);
  // console.log(receipt);
}

deployFunc.tags = ['005_multibridge_setup'];
deployFunc.dependencies = [];
export default deployFunc;
