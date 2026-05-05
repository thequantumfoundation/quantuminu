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
  const initialSupplyRecipient = requireAddress("INITIAL_SUPPLY_RECIPIENT");
  const adminOwner = requireAddress("ADMIN_OWNER");

  if (adminOwner === deployer.address && process.env.ALLOW_DEPLOYER_ADMIN !== "true") {
    throw new Error("ADMIN_OWNER is the deployer address. Set it to your boss/admin wallet, or set ALLOW_DEPLOYER_ADMIN=true for a temporary/admin-transfer deployment.");
  }

  if (adminOwner === initialSupplyRecipient && process.env.ALLOW_ADMIN_SUPPLY_RECIPIENT !== "true") {
    throw new Error("ADMIN_OWNER is the initial supply recipient. Use separate wallets, or set ALLOW_ADMIN_SUPPLY_RECIPIENT=true if this is intentional.");
  }

  const QINU = await hre.ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy({
    initialSupplyRecipient,
    burnReserve: requireAddress("BURN_RESERVE"),
    taxTreasury: requireAddress("TAX_TREASURY"),
    adminOwner
  });

  await qinu.waitForDeployment();
  const owner = await qinu.owner();

  if (owner !== adminOwner) {
    throw new Error(`Unexpected owner ${owner}; expected ${adminOwner}`);
  }

  const recipientBalance = await qinu.balanceOf(initialSupplyRecipient);
  const totalSupply = await qinu.totalSupply();

  if (recipientBalance !== totalSupply) {
    throw new Error(`Unexpected initial supply recipient balance ${recipientBalance}; expected ${totalSupply}`);
  }

  console.log(`Deployer: ${deployer.address}`);
  console.log(`Admin/owner: ${owner}`);
  console.log(`Initial supply recipient: ${initialSupplyRecipient}`);
  console.log(`QINU deployed to ${qinu.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});