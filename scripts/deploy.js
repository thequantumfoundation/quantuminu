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
  const adminMultisig = requireAddress("ADMIN_MULTISIG");

  if (adminMultisig === deployer.address && process.env.ALLOW_DEPLOYER_ADMIN !== "true") {
    throw new Error("ADMIN_MULTISIG is the deployer address. Set it to your boss/multisig address, or set ALLOW_DEPLOYER_ADMIN=true for a temporary/admin-transfer deployment.");
  }

  const QINU = await hre.ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy({
    tippingSocial: requireAddress("TIPPING_SOCIAL"),
    stakingRewardsPool: requireAddress("STAKING_REWARDS_POOL"),
    airdrops: requireAddress("AIRDROPS"),
    memeTreasury: requireAddress("MEME_TREASURY"),
    liquidity: requireAddress("LIQUIDITY"),
    ecosystemFund: requireAddress("ECOSYSTEM_FUND"),
    foundationTreasury: requireAddress("FOUNDATION_TREASURY"),
    burnReserve: requireAddress("BURN_RESERVE"),
    teamVesting: requireAddress("TEAM_VESTING"),
    seedVesting: requireAddress("SEED_VESTING"),
    taxTreasury: requireAddress("TAX_TREASURY"),
    adminMultisig
  });

  await qinu.waitForDeployment();
  const owner = await qinu.owner();

  if (owner !== adminMultisig) {
    throw new Error(`Unexpected owner ${owner}; expected ${adminMultisig}`);
  }

  console.log(`Deployer: ${deployer.address}`);
  console.log(`Admin/owner: ${owner}`);
  console.log(`QINU deployed to ${qinu.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});