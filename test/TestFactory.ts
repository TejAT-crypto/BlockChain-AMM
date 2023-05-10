import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { AddressZero, bigNumberify, getCreate2Address } from '../utils/shared';

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000',
];

describe('Factory', () => {
  const deployFactoryFixture = async () => {
    const [owner, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('Factory');
    const DExPair = await ethers.getContractFactory('DExPair');
    const factory = await Factory.deploy(owner.address);
    return { factory, DExPair, owner, other };
  };

  const createPairs = async (tokens: [string, string]) => {
    const { factory, DExPair } = await loadFixture(deployFactoryFixture);
    const bytecode = DExPair.bytecode;
    const create2Address = getCreate2Address(factory.address, tokens, bytecode);
    await expect(factory.createPairs(...tokens))
      .to.emit(factory, 'CreatedPair')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, bigNumberify(1));
    const tokensReversed = tokens.slice().reverse() as [string, string];
    await expect(factory.createPairs(...tokens)).to.be.revertedWithCustomError(factory, 'PairExist');
    await expect(factory.createPairs(...tokensReversed)).to.be.revertedWithCustomError(factory, 'PairExist'); 
    // expect(await factory.getPair(...tokens)).to.eq(create2Address);
    // expect(await factory.getPair(...tokensReversed)).to.eq(create2Address);
    //expect(await factory.allPairs(0)).to.eq(create2Address);
    expect(await factory.allPairLength()).to.eq(1);

    const pair = DExPair.attach(create2Address);
    expect(await pair.factory()).to.eq(factory.address);
    expect(await pair.tokenA()).to.eq(TEST_ADDRESSES[0]);
    expect(await pair.tokenB()).to.eq(TEST_ADDRESSES[1]);
  };

  it('feesTo, allPairLength', async () => {
    const { factory, owner } = await loadFixture(deployFactoryFixture);
    expect(await factory.feesTo()).to.eq(AddressZero);
    expect(await factory.feesToSetter()).to.eq(owner.address);
    expect(await factory.allPairLength()).to.eq(0);
  });

  it('createPairs', async () => {
    await createPairs(TEST_ADDRESSES);
  });

  it('createPairs:reverse', async () => {
    await createPairs(TEST_ADDRESSES.slice().reverse() as [string, string]);
  });

  it('_setFeesTo', async () => {
    const { factory, other, owner } = await loadFixture(deployFactoryFixture);
    await expect(factory.connect(other)._setFeesTo(other.address))
      .to.be.revertedWithCustomError(factory, 'IsForbidden')
      .withArgs(other.address, owner.address);
    await factory._setFeesTo(other.address);
    expect(await factory.feesTo()).to.eq(other.address);
  });

  it('_setFeesToSetter', async () => {
    const { factory, owner, other } = await loadFixture(deployFactoryFixture);
    await expect(factory.connect(other)._setFeesToSetter(other.address))
      .to.be.revertedWithCustomError(factory, 'IsForbidden')
      .withArgs(other.address, owner.address);
    await factory._setFeesToSetter(other.address);
    expect(await factory.feesToSetter()).to.eq(other.address);
    await expect(factory._setFeesToSetter(owner.address))
      .to.be.revertedWithCustomError(factory, 'IsForbidden')
      .withArgs(owner.address, other.address);
  });
});