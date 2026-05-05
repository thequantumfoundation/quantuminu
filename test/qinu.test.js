const { expect } = require("chai");
const { ethers } = require("hardhat");

const parse = ethers.parseEther;
const MAINNET_INITIAL_SUPPLY_RECIPIENT = "0x40ed2bf6557630e9184455da43a2df5149171b14";

async function deployQinu() {
  const signers = await ethers.getSigners();
  const [admin, initialSupplyRecipient, burnReserve, taxTreasury, user, recipient] = signers;

  const QINU = await ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy(initialSupplyRecipient.address, burnReserve.address, taxTreasury.address, admin.address);

  return { qinu, signers, admin, initialSupplyRecipient, burnReserve, taxTreasury, user, recipient };
}

describe("QINU", function () {
  it("lets a deployer assign ownership directly to a separate admin wallet", async function () {
    const [deployer, bossAdmin, initialSupplyRecipient, burnReserve, taxTreasury] = await ethers.getSigners();
    const QINU = await ethers.getContractFactory("QINU", deployer);
    const qinu = await QINU.deploy(initialSupplyRecipient.address, burnReserve.address, taxTreasury.address, bossAdmin.address);

    expect(await qinu.owner()).to.equal(bossAdmin.address);
    expect(await qinu.balanceOf(initialSupplyRecipient.address)).to.equal(parse("1000000000000"));
    await expect(qinu.connect(deployer).setTaxEnabled(false)).to.be.revertedWithCustomError(qinu, "OwnableUnauthorizedAccount");
    await qinu.connect(bossAdmin).setTaxEnabled(false);
    expect(await qinu.taxEnabled()).to.equal(false);
  });

  it("mints the complete fixed supply to the initial supply recipient", async function () {
    const { qinu, initialSupplyRecipient, burnReserve } = await deployQinu();

    expect(await qinu.name()).to.equal("Quantum Inu");
    expect(await qinu.symbol()).to.equal("QINU");
    expect(await qinu.decimals()).to.equal(18);
    expect(await qinu.totalSupply()).to.equal(parse("1000000000000"));
    expect(await qinu.balanceOf(initialSupplyRecipient.address)).to.equal(parse("1000000000000"));
    expect(await qinu.balanceOf(burnReserve.address)).to.equal(0);
  });

  it("supports the configured mainnet initial supply recipient wallet", async function () {
    const [admin, burnReserve, taxTreasury] = await ethers.getSigners();
    const QINU = await ethers.getContractFactory("QINU");
    const qinu = await QINU.deploy(MAINNET_INITIAL_SUPPLY_RECIPIENT, burnReserve.address, taxTreasury.address, admin.address);

    expect(await qinu.balanceOf(MAINNET_INITIAL_SUPPLY_RECIPIENT)).to.equal(await qinu.totalSupply());
  });

  it("applies the 2% transfer tax split", async function () {
    const { qinu, initialSupplyRecipient, taxTreasury, user, recipient } = await deployQinu();
    const amount = parse("1000000");

    await qinu.connect(initialSupplyRecipient).transfer(user.address, parse("10000000"));
    await qinu.connect(user).transfer(recipient.address, amount);

    expect(await qinu.balanceOf(recipient.address)).to.be.gte(parse("980000"));
    expect(await qinu.balanceOf(taxTreasury.address)).to.equal(parse("5000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999995000"));
    expect(await qinu.totalFeesReflected()).to.equal(parse("10000"));
  });

  it("enforces launch max tx and max wallet limits", async function () {
    const { qinu, initialSupplyRecipient, user, recipient } = await deployQinu();

    await qinu.setMaxWallet(parse("1000000000000"));
    await qinu.connect(initialSupplyRecipient).transfer(user.address, parse("3000000000"));
    await expect(qinu.connect(user).transfer(recipient.address, parse("3000000000"))).to.be.revertedWith("QINU: max tx exceeded");

    await qinu.setMaxTx(parse("10000000000"));
    await qinu.setMaxWallet(parse("5000000000"));
    await expect(qinu.connect(initialSupplyRecipient).transfer(recipient.address, parse("6000000000"))).to.be.revertedWith("QINU: max wallet exceeded");
  });

  it("allows admin to trigger reserve burns after the reserve is funded", async function () {
    const { qinu, initialSupplyRecipient, burnReserve } = await deployQinu();

    await qinu.connect(initialSupplyRecipient).transfer(burnReserve.address, parse("10000000"));

    await qinu.triggerReactiveBurn(parse("1000000"));

    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("9000000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999000000"));
  });

  it("caps reflection exclusions to keep transfers gas-bounded", async function () {
    const { qinu } = await deployQinu();
    const maxExclusions = Number(await qinu.MAX_REFLECTION_EXCLUSIONS());
    const initiallyExcluded = 4;

    for (let index = 0; index < maxExclusions - initiallyExcluded; index++) {
      const account = ethers.getAddress(`0x${(index + 1).toString(16).padStart(40, "0")}`);
      await qinu.excludeFromReflection(account, true);
    }

    await expect(qinu.excludeFromReflection("0x0000000000000000000000000000000000000100", true)).to.be.revertedWith("QINU: too many reflection exclusions");
  });
});

describe("QINUVesting", function () {
  it("releases vested tokens after the cliff", async function () {
    const [owner, beneficiary] = await ethers.getSigners();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token = await MockERC20.deploy("Mock", "MOCK");
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const Vesting = await ethers.getContractFactory("QINUVesting");
    const vesting = await Vesting.deploy(token.target, beneficiary.address, now, 365 * 24 * 60 * 60, 4 * 365 * 24 * 60 * 60, parse("1000"));

    await token.mint(vesting.target, parse("1000"));
    await ethers.provider.send("evm_increaseTime", [2 * 365 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await vesting.release();
    expect(await token.balanceOf(beneficiary.address)).to.be.closeTo(parse("500"), parse("1"));
    expect(await token.balanceOf(owner.address)).to.equal(0);
  });
});

describe("QINUStaking", function () {
  it("lets a deployer assign staking ownership directly to a separate admin wallet", async function () {
    const [deployer, bossAdmin] = await ethers.getSigners();
    const MockERC20 = await ethers.getContractFactory("MockERC20", deployer);
    const qinu = await MockERC20.deploy("Quantum Inu", "QINU");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking", deployer);
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), bossAdmin.address);

    await qinu.mint(bossAdmin.address, parse("1000"));
    await qinu.connect(bossAdmin).approve(staking.target, parse("1000"));

    expect(await staking.owner()).to.equal(bossAdmin.address);
    await expect(staking.connect(deployer).fundRewards(parse("1000"))).to.be.revertedWithCustomError(staking, "OwnableUnauthorizedAccount");
    await staking.connect(bossAdmin).fundRewards(parse("1000"));
    expect(await staking.rewardReserve()).to.equal(parse("1000"));
  });

  it("accrues decaying rewards for single staking", async function () {
    const [admin, user] = await ethers.getSigners();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const qinu = await MockERC20.deploy("Quantum Inu", "QINU");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking");
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), admin.address);

    await qinu.mint(admin.address, parse("1000000"));
    await qinu.approve(staking.target, parse("1000000"));
    await staking.fundRewards(parse("1000000"));
    await qinu.mint(user.address, parse("1000"));
    await qinu.connect(user).approve(staking.target, parse("1000"));
    await staking.connect(user).stake(parse("1000"));
    await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    expect(await staking.pendingRewards(user.address)).to.be.gt(0);
    await staking.connect(user).claimRewards();
    expect(await qinu.balanceOf(user.address)).to.be.gt(0);
  });

  it("does not pay rewards from staked principal when rewards are unfunded", async function () {
    const [admin, user] = await ethers.getSigners();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const qinu = await MockERC20.deploy("Quantum Inu", "QINU");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking");
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), admin.address);

    await qinu.mint(user.address, parse("1000"));
    await qinu.connect(user).approve(staking.target, parse("1000"));
    await staking.connect(user).stake(parse("1000"));
    await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await expect(staking.connect(user).claimRewards()).to.be.revertedWith("Staking: insufficient reward reserve");
    expect(await qinu.balanceOf(staking.target)).to.equal(parse("1000"));
  });

  it("rejects taxed QINU deposits that would break staking accounting", async function () {
    const { qinu, initialSupplyRecipient, user, admin } = await deployQinu();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking");
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), admin.address);

    await qinu.connect(initialSupplyRecipient).transfer(user.address, parse("1000"));
    await qinu.connect(user).approve(staking.target, parse("100"));

    await expect(staking.connect(user).stake(parse("100"))).to.be.revertedWith("Staking: fee token unsupported");
  });
});