const hre = require("hardhat");

const ownableAbi = [
  "function owner() view returns (address)",
  "function transferOwnership(address newOwner)"
];

function requireAddress(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing ${name}`);
  }
  return hre.ethers.getAddress(value);
}

function contractAddresses() {
  const singleAddress = process.env.CONTRACT_ADDRESS;
  const multipleAddresses = process.env.CONTRACT_ADDRESSES;

  if (!singleAddress && !multipleAddresses) {
    throw new Error("Missing CONTRACT_ADDRESS or CONTRACT_ADDRESSES");
  }

  return (multipleAddresses || singleAddress)
    .split(",")
    .map((address) => hre.ethers.getAddress(address.trim()))
    .filter((address) => address !== hre.ethers.ZeroAddress);
}

async function main() {
  const [sender] = await hre.ethers.getSigners();
  const newAdmin = requireAddress("NEW_ADMIN_MULTISIG");
  const addresses = contractAddresses();

  if (newAdmin === sender.address && process.env.ALLOW_DEPLOYER_ADMIN !== "true") {
    throw new Error("NEW_ADMIN_MULTISIG is the sender address. Set it to your boss/multisig address, or set ALLOW_DEPLOYER_ADMIN=true if this is intentional.");
  }

  for (const address of addresses) {
    const contract = new hre.ethers.Contract(address, ownableAbi, sender);
    const currentOwner = await contract.owner();

    if (currentOwner !== sender.address) {
      throw new Error(`Sender ${sender.address} is not owner of ${address}; current owner is ${currentOwner}`);
    }

    const tx = await contract.transferOwnership(newAdmin);
    await tx.wait();

    const updatedOwner = await contract.owner();
    if (updatedOwner !== newAdmin) {
      throw new Error(`Ownership transfer failed for ${address}; owner is ${updatedOwner}`);
    }

    console.log(`Transferred ${address} ownership from ${currentOwner} to ${updatedOwner}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
