const { expect } = require("chai");

describe("Factory", function () {
    let Factory;
    let factory;
    let TokenA;
    let TokenB;
    let owner;

    beforeEach(async function () {
        Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy();
        await factory.deployed();

        TokenA = await ethers.getContractAt("IERC20", "0x1");
        TokenB = await ethers.getContractAt("IERC20", "0x2");
        owner = await ethers.getSigner();
    });

    it("should create a new pair", async function () {
        const pair = await factory.createPairs(
            TokenA.address,
            TokenB.address
        );

        const dexPair = await ethers.getContractAt("DExPair", pair);

        // Check pair addresses
        const pairA = await factory.newPairs(TokenA.address, TokenB.address);
        const pairB = await factory.newPairs(TokenB.address, TokenA.address);
        expect(pairA).to.equal(pair);
        expect(pairB).to.equal(pair);

        // Check pair tokens
        expect(await dexPair.token0()).to.equal(TokenA.address);
        expect(await dexPair.token1()).to.equal(TokenB.address);

        // Check pair owner
        expect(await dexPair.owner()).to.equal(owner.address);
    });

    it("should revert on creating a pair with same addresses", async function () {
        await expect(
            factory.createPairs(TokenA.address, TokenA.address)
        ).to.be.revertedWith("SameAddresses()");
    });

    it("should revert on creating a pair with zero address", async function () {
        await expect(
            factory.createPairs(TokenA.address, ethers.constants.AddressZero)
        ).to.be.revertedWith("ZeroAddress()");
    });

    it("should revert on creating an existing pair", async function () {
        await factory.createPairs(TokenA.address, TokenB.address);

        await expect(
            factory.createPairs(TokenA.address, TokenB.address)
        ).to.be.revertedWith("PairExist()");
    });
});
