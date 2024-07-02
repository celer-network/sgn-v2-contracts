import { expect } from 'chai';
import { AbiCoder, parseUnits, solidityPackedKeccak256, Wallet, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Bridge, GovernedOwnerProxy, PeggedTokenBridge, SimpleGovernance, TestERC20 } from '../typechain';
import { advanceBlockTime, deployBridgeContracts, deployGovernedOwner, getAccounts } from './lib/common';
import * as consts from './lib/constants';

describe('GovernedOwner Tests', function () {
  const initVoterNum = 4;
  const InitFastPassThreshold = 40;
  const abiCoder = AbiCoder.defaultAbiCoder();

  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { bridge, token, pegBridge } = await deployBridgeContracts(admin);
    const { gov, proxy } = await deployGovernedOwner(admin, initVoterNum);
    return { admin, bridge, token, pegBridge, gov, proxy };
  }

  let bridge: Bridge;
  let token: TestERC20;
  let pegBridge: PeggedTokenBridge;
  let gov: SimpleGovernance;
  let proxy: GovernedOwnerProxy;
  let voters: Wallet[];

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    bridge = res.bridge;
    token = res.token;
    pegBridge = res.pegBridge;
    gov = res.gov;
    proxy = res.proxy;
    voters = await getAccounts(res.admin, [], 5);
    const govAddress = await gov.getAddress();
    await bridge.transferOwnership(govAddress);
    await pegBridge.transferOwnership(govAddress);
  });

  it('should pass param change tests', async function () {
    expect(await gov.params(consts.GovParamFastPassThreshold)).to.equal(InitFastPassThreshold);

    const newThreshold = 10;
    await expect(gov.connect(voters[0]).createParamChangeProposal(consts.GovParamFastPassThreshold, newThreshold))
      .to.emit(gov, 'ParamChangeProposalCreated')
      .withArgs(0, consts.GovParamFastPassThreshold, 10);

    const data = abiCoder.encode(['uint8', 'uint256'], [consts.GovParamFastPassThreshold, 10]);
    await expect(
      gov.connect(voters[2]).executeProposal(0, consts.GovInternalParamChange, ZeroAddress, data)
    ).to.be.revertedWith('not enough votes');

    await gov.connect(voters[1]).voteProposal(0, true);

    await expect(gov.connect(voters[2]).executeProposal(0, consts.GovInternalParamChange, ZeroAddress, data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(0);

    expect(await gov.params(consts.GovParamFastPassThreshold)).to.equal(newThreshold);
  });

  it('should pass voter and proxy update tests', async function () {
    // voter update tests
    expect((await gov.getVoters())[0]).to.deep.equal([
      voters[0].address,
      voters[1].address,
      voters[2].address,
      voters[3].address
    ]);
    await expect(gov.connect(voters[0]).createVoterUpdateProposal([voters[1].address, voters[4].address], [0, 100]))
      .to.emit(gov, 'VoterUpdateProposalCreated')
      .withArgs(0, [voters[1].address, voters[4].address], [0, 100]);

    await gov.connect(voters[1]).voteProposal(0, true);

    let data = abiCoder.encode(
      ['address[]', 'uint256[]'],
      [
        [voters[1].address, voters[4].address],
        [0, 100]
      ]
    );
    await expect(gov.connect(voters[2]).executeProposal(0, consts.GovInternalVoterUpdate, ZeroAddress, data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(0);

    expect((await gov.getVoters())[0]).to.deep.equal([
      voters[0].address,
      voters[3].address,
      voters[2].address,
      voters[4].address
    ]);
    expect(await gov.voterPowers(voters[1].address)).to.equal(0);
    expect(await gov.voterPowers(voters[4].address)).to.equal(100);

    // proxy update tests
    expect(await gov.proposerProxies(proxy.getAddress())).to.equal(true);
    await expect(
      gov.connect(voters[4]).createProxyUpdateProposal([proxy.getAddress(), voters[3].address], [false, true])
    )
      .to.emit(gov, 'ProxyUpdateProposalCreated')
      .withArgs(1, [await proxy.getAddress(), voters[3].address], [false, true]);

    await gov.connect(voters[0]).voteProposal(1, true);

    data = abiCoder.encode(
      ['address[]', 'bool[]'],
      [
        [await proxy.getAddress(), voters[3].address],
        [false, true]
      ]
    );
    await expect(gov.connect(voters[2]).executeProposal(1, consts.GovInternalProxyUpdate, ZeroAddress, data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(1);

    expect(await gov.proposerProxies(proxy.getAddress())).to.equal(false);
    expect(await gov.proposerProxies(voters[3].address)).to.equal(true);
  });

  it('should pass transfer token tests', async function () {
    expect(await token.balanceOf(voters[0].address)).to.equal(0);

    const amount = parseUnits('1');
    await token.transfer(gov.getAddress(), amount);
    await expect(gov.connect(voters[0]).createTransferTokenProposal(voters[0].address, token.getAddress(), amount))
      .to.emit(gov, 'TransferTokenProposalCreated')
      .withArgs(0, voters[0].address, token.getAddress(), amount);
    await gov.connect(voters[1]).voteProposal(0, true);
    const data = abiCoder.encode(
      ['address', 'address', 'uint256'],
      [voters[0].address, await token.getAddress(), amount]
    );
    await expect(gov.connect(voters[2]).executeProposal(0, consts.GovInternalTokenTransfer, ZeroAddress, data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(0);

    expect(await token.balanceOf(voters[0].address)).to.equal(amount);
  });

  it('should pass common owner proxy tests', async function () {
    // proposal 0: add pauser - success
    const pauser = voters[2].address;
    await expect(proxy.connect(voters[0]).proposeUpdatePauser(bridge.getAddress(), 1, pauser))
      .to.emit(proxy, 'UpdatePauserProposalCreated')
      .withArgs(0, bridge.getAddress(), 1, pauser);

    let data = (await bridge.addPauser.populateTransaction(pauser)).data || '';
    await expect(
      gov.connect(voters[3]).executeProposal(0, consts.GovExternalFastPass, bridge.getAddress(), '0x01')
    ).to.be.revertedWith('data hash not match');
    await expect(
      gov.connect(voters[3]).executeProposal(0, consts.GovExternalFastPass, voters[0].address, data)
    ).to.be.revertedWith('data hash not match');
    await expect(gov.connect(voters[3]).executeProposal(0, consts.GovExternalFastPass, bridge.getAddress(), data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(0)
      .to.emit(bridge, 'PauserAdded')
      .withArgs(pauser);

    // proposal 1: remove pauser - fail due to timeout
    await expect(proxy.connect(voters[0]).proposeUpdatePauser(bridge.getAddress(), 2, pauser))
      .to.emit(proxy, 'UpdatePauserProposalCreated')
      .withArgs(1, bridge.getAddress(), 2, pauser);
    await advanceBlockTime(10000);
    data = (await bridge.removePauser.populateTransaction(pauser)).data || '';
    await expect(
      gov.connect(voters[1]).executeProposal(1, consts.GovExternalFastPass, bridge.getAddress(), data)
    ).to.be.revertedWith('deadline passed');
    await expect(gov.connect(voters[1]).voteProposal(1, true)).to.be.revertedWith('deadline passed');

    // proposal 2: transfer ownership
    expect(await bridge.owner()).to.equal(await gov.getAddress());

    const newOwner = voters[0].address;
    await expect(proxy.connect(voters[0]).proposeTransferOwnership(bridge.getAddress(), newOwner))
      .to.emit(proxy, 'TransferOwnershipProposalCreated')
      .withArgs(2, bridge.getAddress(), newOwner);

    data = (await bridge.transferOwnership.populateTransaction(newOwner)).data || '';
    await expect(
      gov.connect(voters[1]).executeProposal(2, consts.GovExternalDefault, bridge.getAddress(), data)
    ).to.be.revertedWith('not enough votes');
    await gov.connect(voters[1]).voteProposal(2, true);
    await expect(gov.voteProposal(0, true)).to.be.revertedWith('invalid voter');

    await gov.connect(voters[2]).executeProposal(2, consts.GovExternalDefault, bridge.getAddress(), data);
    expect(await bridge.owner()).to.equal(newOwner);

    await expect(
      gov.connect(voters[2]).executeProposal(2, consts.GovExternalDefault, bridge.getAddress(), data)
    ).to.be.revertedWith('deadline passed');
  });

  it('should pass bridge owner proxy tests', async function () {
    // reset signers
    await expect(proxy.connect(voters[0]).proposeResetSigners(bridge.getAddress(), [voters[0].address], [1000]))
      .to.emit(proxy, 'ResetSignersProposalCreated')
      .withArgs(0, bridge.getAddress(), [voters[0].address], [1000]);

    await gov.connect(voters[1]).voteProposal(0, true);

    let data = (await bridge.resetSigners.populateTransaction([voters[0].address], [1000])).data || '';
    await expect(gov.connect(voters[2]).executeProposal(0, consts.GovExternalDefault, bridge.getAddress(), data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(0)
      .to.emit(bridge, 'SignersUpdated')
      .withArgs([voters[0].address], [1000]);

    expect(await bridge.ssHash()).to.equal(
      solidityPackedKeccak256(['address[]', 'uint256[]'], [[voters[0].address], [1000]])
    );

    // update governor
    await expect(proxy.connect(voters[0]).proposeUpdateGovernor(bridge.getAddress(), 1, voters[0].address))
      .to.emit(proxy, 'UpdateGovernorProposalCreated')
      .withArgs(1, bridge.getAddress(), 1, voters[0].address);

    data = (await bridge.addGovernor.populateTransaction(voters[0].address)).data || '';
    await expect(gov.connect(voters[2]).executeProposal(1, consts.GovExternalFastPass, bridge.getAddress(), data))
      .to.emit(gov, 'ProposalExecuted')
      .withArgs(1)
      .to.emit(bridge, 'GovernorAdded')
      .withArgs(voters[0].address);
  });
});
