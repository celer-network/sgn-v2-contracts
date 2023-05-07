import * as dotenv from 'dotenv';
import {DeployFunction} from 'hardhat-deploy/types';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();

    const transferMultiTest = await deploy('TransferMultiTest', {
        from: deployer,
        log: true,
        args: []
    });
    await hre.run('verify:verify', {address: transferMultiTest.address});
};

deployFunc.tags = ['TransferMultiTest'];
deployFunc.dependencies = [];
export default deployFunc;
