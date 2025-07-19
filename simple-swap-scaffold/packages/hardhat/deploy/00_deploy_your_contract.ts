import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { Contract } from "ethers";

const deployYourContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts(); // <- este será 0xeAFD... si en config pusiste default: 1

  console.log("Deployer address:", deployer);

  // 1. Deploy TokenA
  const tokenADeployment = await deploy("TokenA", {
    from: deployer,
    args: [],
    log: true,
  });
  const tokenA = await ethers.getContractAt("TokenA", tokenADeployment.address);

  // 2. Deploy TokenB
  const tokenBDeployment = await deploy("TokenB", {
    from: deployer,
    args: [],
    log: true,
  });
  const tokenB = await ethers.getContractAt("TokenB", tokenBDeployment.address);

  // 3. Deploy SimpleSwap
  const swapDeployment = await deploy("SimpleSwap", {
    from: deployer,
    args: [],
    log: true,
  });
  const simpleSwap = await ethers.getContractAt("SimpleSwap", swapDeployment.address);

  // 4. Mint tokens to deployer
  const amountToMint = ethers.parseUnits("1000", 18);
  await tokenA.mint(deployer, amountToMint);
  await tokenB.mint(deployer, amountToMint);
  console.log("Minted 1000 TKA & 1000 TKB to deployer");

  // 5. Approve SimpleSwap to move tokens
  await tokenA.approve(simpleSwap.target, amountToMint);
  await tokenB.approve(simpleSwap.target, amountToMint);
  console.log("Approved SimpleSwap to spend deployer's tokens");

  // 6. Add initial liquidity
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
  const amountADesired = ethers.parseUnits("100", 18);
  const amountBDesired = ethers.parseUnits("200", 18);
  const amountAMin = ethers.parseUnits("90", 18);
  const amountBMin = ethers.parseUnits("180", 18);

  const tx = await simpleSwap.addLiquidity(
    tokenA.target,
    tokenB.target,
    amountADesired,
    amountBDesired,
    amountAMin,
    amountBMin,
    deployer,
    deadline
  );
  await tx.wait();
  console.log("Liquidity added to SimpleSwap!");
};

export default deployYourContract;
deployYourContract.tags = ["SimpleSwap", "TokenA", "TokenB"];