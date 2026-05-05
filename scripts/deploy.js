const hre = require("hardhat");

function requireAddress(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing ${name}`);
  }
  return hre.ethers.getAddress(value);
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const tippingSocial = requireAddress("TIPPING_SOCIAL");
  const stakingRewardsPool = requireAddress("STAKING_REWARDS_POOL");
  const airdrops = requireAddress("AIRDROPS");
  const memeTreasury = requireAddress("MEME_TREASURY");
  const liquidity = requireAddress("LIQUIDITY");
  const ecosystemFund = requireAddress("ECOSYSTEM_FUND");
  const foundationTreasury = requireAddress("FOUNDATION_TREASURY");
  const burnReserve = requireAddress("BURN_RESERVE");
  const team = requireAddress("TEAM");
  const publicSale = requireAddress("PUBLIC_SALE");
  const taxTreasury = requireAddress("TAX_TREASURY");
  const adminOwner = requireAddress("ADMIN_OWNER");

  if (adminOwner === deployer.address && process.env.ALLOW_DEPLOYER_ADMIN !== "true") {
    throw new Error("ADMIN_OWNER is the deployer address. Set it to your boss/admin wallet, or set ALLOW_DEPLOYER_ADMIN=true for a temporary/admin-transfer deployment.");
  }

  const QINU = await hre.ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy(
    tippingSocial,
    stakingRewardsPool,
    airdrops,
    memeTreasury,
    liquidity,
    ecosystemFund,
    foundationTreasury,
    burnReserve,
    team,
    publicSale,
    taxTreasury,
    adminOwner
  );

  await qinu.waitForDeployment();
  const owner = await qinu.owner();

  if (owner !== adminOwner) {
    throw new Error(`Unexpected owner ${owner}; expected ${adminOwner}`);
  }

  const totalSupply = await qinu.totalSupply();

  console.log(`Deployer: ${deployer.address}`);
  console.log(`Admin/owner: ${owner}`);
  console.log(`Total supply: ${totalSupply}`);
  console.log(`QINU deployed to ${qinu.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});