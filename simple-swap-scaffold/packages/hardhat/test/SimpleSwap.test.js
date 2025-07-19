const { expect } = require("chai");
const hre = require("hardhat");
const { ethers } = hre;

describe("SimpleSwap", function () {
  let SimpleSwap, simpleSwap, TokenA, tokenA, TokenB, tokenB, owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    TokenA = await ethers.getContractFactory("TokenA");
    tokenA = await TokenA.deploy(); // ¡NO uses .deployed()!

    TokenB = await ethers.getContractFactory("TokenB");
    tokenB = await TokenB.deploy();

    SimpleSwap = await ethers.getContractFactory("SimpleSwap");
    simpleSwap = await SimpleSwap.deploy();

    // Mint tokens y approve para el owner
    await tokenA.mint(owner.address, ethers.parseEther("1000"));
    await tokenB.mint(owner.address, ethers.parseEther("1000"));

    await tokenA.approve(simpleSwap.target, ethers.parseEther("1000"));
    await tokenB.approve(simpleSwap.target, ethers.parseEther("1000"));
  });

  it("should deploy and have correct LP token name", async function () {
    expect(await simpleSwap.name()).to.equal("Token SimpleSwap");
    expect(await simpleSwap.symbol()).to.equal("TSS");
  });

  it("should add liquidity and mint LP tokens", async function () {
    const amountA = ethers.parseEther("100");
    const amountB = ethers.parseEther("200");

    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      amountA,
      amountB,
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
    const lpBalance = await simpleSwap.balanceOf(owner.address);
    expect(lpBalance).to.be.gt(0);
  });

  it("should get correct price after liquidity", async function () {
    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      ethers.parseEther("100"),
      ethers.parseEther("200"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
    const price = await simpleSwap.getPrice(tokenA.target, tokenB.target);
    expect(price).to.equal(ethers.parseEther("2"));
  });

  it("should swap tokens correctly", async function () {
    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      ethers.parseEther("100"),
      ethers.parseEther("200"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );

    // Mint A para user1 y aprobar
    await tokenA.mint(user1.address, ethers.parseEther("10"));
    await tokenA.connect(user1).approve(simpleSwap.target, ethers.parseEther("10"));

    const path = [tokenA.target, tokenB.target];
    const deadline = Math.floor(Date.now() / 1000) + 3600;

    await simpleSwap.connect(user1).swapExactTokensForTokens(
      ethers.parseEther("10"),
      0,
      path,
      user1.address,
      deadline
    );
    expect(await tokenB.balanceOf(user1.address)).to.be.gt(0);
  });

  it("should remove liquidity and burn LP tokens", async function () {
    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      ethers.parseEther("100"),
      ethers.parseEther("200"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );

    const lpBalance = await simpleSwap.balanceOf(owner.address);

    await simpleSwap.removeLiquidity(
      tokenA.target,
      tokenB.target,
      lpBalance,
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );

    expect(await simpleSwap.balanceOf(owner.address)).to.equal(0);
  });

  it("should calculate getAmountOut correctly", async function () {
    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      ethers.parseEther("100"),
      ethers.parseEther("200"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
    const amountIn = ethers.parseEther("10");
    const reserveIn = ethers.parseEther("100");
    const reserveOut = ethers.parseEther("200");

    const amountOut = await simpleSwap.getAmountOut(amountIn, reserveIn, reserveOut);
    expect(amountOut).to.be.gt(0);
  });
});
