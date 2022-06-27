const { expect } = require("chai");
const { deployments, ethers } = require("hardhat");

describe("ERC721 with Permit", () => {
  // helper to sign using (spender, tokenId, nonce, deadline) EIP 712
  async function sign(spender, tokenId, nonce, deadline) {
    const typedData = {
      types: {
        Permit: [
          { name: "spender", type: "address" },
          { name: "tokenId", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      primaryType: "Permit",
      domain: {
        name: await contract.name(),
        version: "1",
        chainId: chainId,
        verifyingContract: contract.address,
      },
      message: {
        spender,
        tokenId,
        nonce,
        deadline,
      },
    };

    // sign Permit
    const signature = await deployer._signTypedData(
      typedData.domain,
      { Permit: typedData.types.Permit },
      typedData.message
    );

    return signature;
  }

  before(async () => {
    [deployer, bob, alice] = await ethers.getSigners();

    // get chainId
    chainId = await ethers.provider.getNetwork().then((n) => n.chainId);
  });

  beforeEach(async () => {
    const NFTMock = await ethers.getContractFactory("sampleNFT");
    contract = await NFTMock.deploy();
    await contract.deployed();

    // mint tokenId 0 to deployer
    await contract.mint();
  });

  describe("Basic ERC721 contract functionality", async () => {
    it("should read the name and symbol of the contract", async () => {
      expect(await contract.name()).to.be.equal("Mock721");
      expect(await contract.symbol()).to.be.equal("MOCK");
    });

    it("should mint a token with token Id 1 to deployer", async () => {
      await contract.mint();
      expect(await contract.ownerOf(1)).to.be.equal(
        await deployer.getAddress()
      );
      expect(await contract.balanceOf(await deployer.getAddress())).to.be.equal(
        2
      );
    });

    it("should transfer token to bob", async () => {
      await contract.approve(await bob.getAddress(), 0);
      expect(await contract.getApproved(0)).to.be.equal(await bob.getAddress());
      await contract.transferFrom(
        await deployer.getAddress(),
        await bob.getAddress(),
        0
      );
      expect(await contract.ownerOf(0)).to.be.equal(await bob.getAddress());
    });
  });

  describe("Permit functionality", async () => {
    it("nonce increments after each transfer", async () => {
      expect(await contract.getNonce(0)).to.be.equal(0);

      await contract.transferFrom(
        await deployer.getAddress(),
        await bob.getAddress(),
        0
      );

      expect(await contract.getNonce(0)).to.be.equal(1);

      await contract
        .connect(bob)
        .transferFrom(await bob.getAddress(), await deployer.getAddress(), 0);

      expect(await contract.getNonce(0)).to.be.equal(2);
    });

    it("can use permit to get approved", async function () {
      // set deadline in 7 days
      const deadline = parseInt(+new Date() / 1000) + 7 * 24 * 60 * 60;

      // sign Permit for bob
      const signature = await sign(
        await bob.getAddress(),
        0,
        await contract.getNonce(0),
        deadline
      );

      // verify that bob is not approved before permit is used
      expect(await contract.getApproved(0)).to.not.equal(
        await bob.getAddress()
      );

      // use permit
      await contract
        .connect(bob)
        .permit(await bob.getAddress(), 0, deadline, signature);

      // verify that now bob is approved
      expect(await contract.getApproved(0)).to.be.equal(await bob.getAddress());
    });

    it("can not use a permit after a transfer (cause nonce does not match)", async function () {
      // set deadline in 7 days
      const deadline = parseInt(+new Date() / 1000) + 7 * 24 * 60 * 60;

      // sign Permit for bob
      const signature = await sign(
        await bob.getAddress(),
        0,
        await contract.getNonce(0),
        deadline
      );

      // first transfer to alice
      await contract.transferFrom(
        await deployer.getAddress(),
        await alice.getAddress(),
        0
      );

      // then send back to deployer so owner is right (but nonce won't be)
      await contract
        .connect(alice)
        .transferFrom(await alice.getAddress(), await deployer.getAddress(), 0);

      // then try to use permit, should throw because nonce is not valid anymore
      await expect(
        contract
          .connect(bob)
          .permit(await bob.getAddress(), 0, deadline, signature)
      ).to.be.revertedWith("!INVALID_PERMIT_SIGNATURE!");
    });

    it("can not use a permit with right nonce but wrong owner", async function () {
      // first transfer to someone
      await contract.transferFrom(
        await deployer.getAddress(),
        await alice.getAddress(),
        0
      );

      // set deadline in 7 days
      const deadline = parseInt(+new Date() / 1000) + 7 * 24 * 60 * 60;

      // sign Permit for bob
      // Permit will be signed using deployer account, so nonce is right, but owner isn't
      const signature = await sign(
        await bob.getAddress(),
        0,
        1, // nonce is one here
        deadline
      );

      // then try to use permit, should throw because owner is wrong
      await expect(
        contract
          .connect(bob)
          .permit(await bob.getAddress(), 0, deadline, signature)
      ).to.be.revertedWith("!INVALID_PERMIT_SIGNATURE!");
    });
    it("can not use a permit expired", async function () {
      // set deadline 7 days in the past
      const deadline = parseInt(+new Date() / 1000) - 7 * 24 * 60 * 60;

      // sign Permit for bob
      // this Permit is expired as deadline is in the past
      const signature = await sign(
        await bob.getAddress(),
        0,
        await contract.getNonce(0),
        deadline
      );

      await expect(
        contract
          .connect(bob)
          .permit(await bob.getAddress(), 0, deadline, signature)
      ).to.be.revertedWith("!PERMIT_DEADLINE_EXPIRED!");
    });

    it("can use permit to get approved and transfer in the same tx (safeTransferwithPermit)", async function () {
      // set deadline in 7 days
      const deadline = parseInt(+new Date() / 1000) + 7 * 24 * 60 * 60;

      // sign Permit for bob
      const signature = await sign(
        await bob.getAddress(),
        0,
        await contract.getNonce(0),
        deadline
      );

      expect(await contract.getApproved(0)).to.not.equal(
        await bob.getAddress()
      );

      await contract
        .connect(bob)
        .safeTransferFromWithPermit(
          await deployer.getAddress(),
          await bob.getAddress(),
          0,
          [],
          deadline,
          signature
        );

      expect(await contract.ownerOf(0)).to.be.equal(await bob.getAddress());
    });
  });
});
