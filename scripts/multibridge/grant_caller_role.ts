import {getDeployerSigner, getFeeOverrides, waitTx} from "../common";
import {MockCaller__factory} from "../../typechain";

const mockCallerAddr = process.env.MULTI_BRIDGE_MOCK_CALLER as string;

async function grantCallerRole(): Promise<void> {
    const deployerSigner = await getDeployerSigner();
    const feeOverrides = await getFeeOverrides();

    if (!mockCallerAddr) {
        return;
    }
    const mockCaller = MockCaller__factory.connect(mockCallerAddr, deployerSigner);

    const grantedCallerAddr = process.env.MULTI_BRIDGE_GRANTED_CALLER as string || deployerSigner.address;
    console.log("grantRole CALLER_ROLE: ", grantedCallerAddr);
    const CALLER_ROLE = await mockCaller.CALLER_ROLE();
    let tx = await mockCaller.grantRole(CALLER_ROLE, grantedCallerAddr, feeOverrides);
    await waitTx(tx);
}

grantCallerRole();