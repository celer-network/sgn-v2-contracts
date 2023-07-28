import { Wallet } from '@ethersproject/wallet';
import { Bridge, PeggedTokenBridge, Sentinel } from '../typechain';
import { deployBridgeContracts, deploySentinel, getAccounts, loadFixture } from './lib/common';
import { expect } from 'chai';

describe('Sentinel Tests', function () {
  async function fixture([admin]: Wallet[]) {
    const { bridge, token, pegBridge } = await deployBridgeContracts(admin);
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
    await sentinel.addGuards([guards[0].address, guards[1].address], true);
    await sentinel.addPausers([pausers[0].address, pausers[1].address], [1, 2]);
    await sentinel.addGovernors([governor.address]);
    await bridge.addPauser(sentinel.address);
    await pegBridge.addPauser(sentinel.address);
  });

  it('should pass pauser tests', async function () {
    await expect(sentinel.connect(governor).functions['pause(address)'](bridge.address)).to.be.revertedWith(
      'invalid caller'
    );

    await expect(sentinel.connect(pausers[1]).functions['pause(address[])']([bridge.address, pegBridge.address]))
      .to.emit(bridge, 'Paused')
      .to.emit(pegBridge, 'Paused');

    await expect(
      sentinel.connect(pausers[0]).functions['pause(address[])']([bridge.address, pegBridge.address])
    ).to.be.revertedWith('pause failed for all targets');

    await expect(
      sentinel.connect(pausers[0]).functions['unpause(address[])']([bridge.address, pegBridge.address])
    ).to.be.revertedWith('not in relaxed mode');

    await sentinel.connect(guards[0]).updateGuardState(2);
    await expect(sentinel.connect(pausers[0]).functions['unpause(address)'](bridge.address)).to.be.revertedWith(
      'not in relaxed mode'
    );

    await sentinel.connect(guards[1]).updateGuardState(2);

    await expect(sentinel.connect(pausers[1]).functions['unpause(address)'](bridge.address)).to.be.revertedWith(
      'invalid caller'
    );
    await expect(sentinel.connect(pausers[0]).functions['unpause(address)'](bridge.address)).to.emit(
      bridge,
      'Unpaused'
    );

    await expect(sentinel.connect(pausers[0]).functions['unpause(address[])']([bridge.address, pegBridge.address]))
      .to.emit(pegBridge, 'Unpaused')
      .to.emit(sentinel, 'Failed')
      .withArgs(bridge.address, 'Pausable: not paused');
  });
});
