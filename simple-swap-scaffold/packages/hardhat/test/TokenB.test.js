const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenB", function () {
  let tokenB;
  let owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const TokenB = await ethers.getContractFactory("TokenB");
    tokenB = await TokenB.deploy();
    await tokenB.waitForDeployment();
  });

  it("should deploy and allow owner to mint tokens", async function () {
    const amount = ethers.parseEther("1000");
    await tokenB.mint(owner.address, amount);
    const balance = await tokenB.balanceOf(owner.address);
    expect(balance).to.equal(amount);
  });
});
