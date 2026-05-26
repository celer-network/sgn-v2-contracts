import { expect } from 'chai';
import { parseUnits, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

describe('RFQ Tests', function () {
  async function fixture() {
    const [admin, receiver, nonOwner] = await ethers.getSigners();

    const tokenFactory = await ethers.getContractFactory('TestERC20');
    const token = await tokenFactory.deploy();
    await token.waitForDeployment();

    const rfqFactory = await ethers.getContractFactory('RFQ');
    const rfq = await rfqFactory.deploy(ZeroAddress);
    await rfq.waitForDeployment();

    return { admin, receiver, nonOwner, token, rfq };
  }

  it('should rescue native tokens by owner', async function () {
    const { admin, receiver, nonOwner, rfq } = await loadFixture(fixture);
    const rfqAddress = await rfq.getAddress();
    const amount = parseUnits('1');

    await admin.sendTransaction({ to: rfqAddress, value: amount });
    expect(await ethers.provider.getBalance(rfqAddress)).to.equal(amount);

    await expect(rfq.connect(nonOwner).rescueToken(ZeroAddress, receiver.address, amount)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );

    await expect(rfq.rescueToken(ZeroAddress, receiver.address, amount))
      .to.emit(rfq, 'TokenRescued')
      .withArgs(receiver.address, ZeroAddress, amount);

    expect(await ethers.provider.getBalance(rfqAddress)).to.equal(0n);
    expect(await ethers.provider.getBalance(receiver.address)).to.equal(parseUnits('10001'));
  });

  it('should rescue ERC20 tokens by owner', async function () {
    const { receiver, nonOwner, token, rfq } = await loadFixture(fixture);
    const rfqAddress = await rfq.getAddress();
    const tokenAddress = await token.getAddress();
    const amount = parseUnits('25');

    await token.transfer(rfqAddress, amount);
    expect(await token.balanceOf(rfqAddress)).to.equal(amount);

    await expect(rfq.connect(nonOwner).rescueToken(tokenAddress, receiver.address, amount)).to.be.revertedWith(
      'Ownable: caller is not the owner'
    );

    await expect(rfq.rescueToken(tokenAddress, receiver.address, amount))
      .to.emit(rfq, 'TokenRescued')
      .withArgs(receiver.address, tokenAddress, amount);

    expect(await token.balanceOf(rfqAddress)).to.equal(0n);
    expect(await token.balanceOf(receiver.address)).to.equal(amount);
  });

  it('should reject rescue to zero address', async function () {
    const { rfq, token } = await loadFixture(fixture);

    await expect(rfq.rescueToken(await token.getAddress(), ZeroAddress, 1)).to.be.revertedWith(
      'Rfq: invalid receiver'
    );
  });
});