const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenA", function () {
  let tokenA;
  let owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const TokenA = await ethers.getContractFactory("TokenA");
    tokenA = await TokenA.deploy();
    await tokenA.waitForDeployment();
  });

  it("should deploy and allow owner to mint tokens", async function () {
    const amount = ethers.parseEther("1000");
    await tokenA.mint(owner.address, amount);
    const balance = await tokenA.balanceOf(owner.address);
    expect(balance).to.equal(amount);
  });
});
