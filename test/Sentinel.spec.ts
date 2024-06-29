import { expect } from 'chai';
import { Wallet } from 'ethers';
import { ethers } from 'hardhat';

import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import { Bridge, PeggedTokenBridge, Sentinel } from '../typechain';
import { deployBridgeContracts, deploySentinel, getAccounts } from './lib/common';

describe('Sentinel Tests', function () {
  async function fixture() {
    const [admin] = await ethers.getSigners();
    const { bridge, pegBridge } = await deployBridgeContracts(admin);
    const sentinel = await deploySentinel(admin);
    return { admin, bridge, pegBridge, sentinel };
  }

  let bridge: Bridge;
  let pegBridge: PeggedTokenBridge;
  let sentinel: Sentinel;
  let guards: Wallet[];
  let pausers: Wallet[];
  let governor: Wallet;

  beforeEach(async () => {
    const res = await loadFixture(fixture);
    const accounts = await getAccounts(res.admin, [], 5);
    bridge = res.bridge;
    pegBridge = res.pegBridge;
    sentinel = res.sentinel;
    guards = [accounts[0], accounts[1]];
    pausers = [accounts[2], accounts[3]];
    governor = accounts[4];
    const sentinelAddress = await sentinel.getAddress();
    await sentinel.updateGuards([guards[0].address, guards[1].address], [], 2);
    await sentinel.addPausers([pausers[0].address, pausers[1].address], [1, 2]);
    await sentinel.addGovernors([governor.address]);
    await bridge.addPauser(sentinelAddress);
    await pegBridge.addPauser(sentinelAddress);
    await bridge.addGovernor(sentinelAddress);
  });

  it('should pass guard tests', async function () {
    await expect(sentinel.updateGuards([pausers[0].address], [], 2))
      .to.emit(sentinel, 'GuardUpdated')
      .withArgs(pausers[0].address, 1);

    expect(await sentinel.numGuards()).to.equal(3);
    expect(await sentinel.relaxThreshold()).to.equal(2);
    expect(await sentinel.numRelaxedGuards()).to.equal(0);

    await sentinel.connect(guards[0]).relax();
    await expect(sentinel.connect(guards[1]).relax()).to.emit(sentinel, 'RelaxStatusUpdated').withArgs(true);

    await expect(sentinel.updateGuards([pausers[1].address], [], 3))
      .to.emit(sentinel, 'RelaxStatusUpdated')
      .withArgs(false);

    expect(await sentinel.numGuards()).to.equal(4);
    expect(await sentinel.relaxThreshold()).to.equal(3);
    expect(await sentinel.numRelaxedGuards()).to.equal(2);

    await expect(sentinel.updateGuards([], [guards[0].address, pausers[0].address], 2))
      .to.emit(sentinel, 'GuardUpdated')
      .withArgs(guards[0].address, 0)
      .to.emit(sentinel, 'GuardUpdated')
      .withArgs(pausers[0].address, 0);
    expect(await sentinel.numGuards()).to.equal(2);
    expect(await sentinel.relaxThreshold()).to.equal(2);
    expect(await sentinel.numRelaxedGuards()).to.equal(1);

    await expect(sentinel.updateGuards([], [pausers[1].address], 1))
      .to.emit(sentinel, 'RelaxStatusUpdated')
      .withArgs(true);
    expect(await sentinel.numGuards()).to.equal(1);
    expect(await sentinel.relaxThreshold()).to.equal(1);
    expect(await sentinel.numRelaxedGuards()).to.equal(1);
  });

  it('should pass pauser tests', async function () {
    await expect(sentinel.connect(governor).getFunction('pause(address)')(bridge.getAddress())).to.be.revertedWith(
      'invalid caller'
    );

    await expect(
      sentinel.connect(pausers[1]).getFunction('pause(address[])')([bridge.getAddress(), pegBridge.getAddress()])
    )
      .to.emit(bridge, 'Paused')
      .to.emit(pegBridge, 'Paused');

    await expect(
      sentinel.connect(pausers[0]).getFunction('pause(address[])')([bridge.getAddress(), pegBridge.getAddress()])
    ).to.be.revertedWith('pause failed for all targets');

    await expect(
      sentinel.connect(pausers[0]).getFunction('unpause(address[])')([bridge.getAddress(), pegBridge.getAddress()])
    ).to.be.revertedWith('not in relaxed mode');

    await sentinel.connect(guards[0]).relax();
    await expect(sentinel.connect(pausers[0]).getFunction('unpause(address)')(bridge.getAddress())).to.be.revertedWith(
      'not in relaxed mode'
    );

    await sentinel.connect(guards[1]).relax();

    await expect(sentinel.connect(pausers[1]).getFunction('unpause(address)')(bridge.getAddress())).to.be.revertedWith(
      'invalid caller'
    );
    await expect(sentinel.connect(pausers[0]).getFunction('unpause(address)')(bridge.getAddress())).to.emit(
      bridge,
      'Unpaused'
    );

    await expect(
      sentinel.connect(pausers[0]).getFunction('unpause(address[])')([bridge.getAddress(), pegBridge.getAddress()])
    )
      .to.emit(pegBridge, 'Unpaused')
      .to.emit(sentinel, 'Failed')
      .withArgs(await bridge.getAddress(), 'Pausable: not paused');
  });

  it('should pass governor tests', async function () {
    await expect(sentinel.connect(governor).setDelayPeriod(bridge.getAddress(), 10))
      .to.emit(bridge, 'DelayPeriodUpdated')
      .withArgs(10);

    await expect(sentinel.connect(governor).setDelayPeriod(bridge.getAddress(), 5)).to.be.revertedWith(
      'not in relax mode, can only increase period'
    );

    await sentinel.connect(guards[0]).relax();
    await sentinel.connect(guards[1]).relax();

    await expect(sentinel.connect(governor).setDelayPeriod(bridge.getAddress(), 5))
      .to.emit(bridge, 'DelayPeriodUpdated')
      .withArgs(5);
  });
});
