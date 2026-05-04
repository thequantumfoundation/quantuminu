const { expect } = require("chai");
const { ethers } = require("hardhat");

const parse = ethers.parseEther;

async function deployQinu() {
  const signers = await ethers.getSigners();
  const [admin, tipping, stakingPool, airdrops, memeTreasury, liquidity, foundationTreasury, burnReserve, teamVesting, seedVesting, taxTreasury, user, recipient] = signers;

  const QINU = await ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy({
    tippingSocial: tipping.address,
    stakingRewardsPool: stakingPool.address,
    airdrops: airdrops.address,
    memeTreasury: memeTreasury.address,
    liquidity: liquidity.address,
    ecosystemFund: signers[13].address,
    foundationTreasury: foundationTreasury.address,
    burnReserve: burnReserve.address,
    teamVesting: teamVesting.address,
    seedVesting: seedVesting.address,
    taxTreasury: taxTreasury.address,
    adminMultisig: admin.address
  });

  return { qinu, signers, admin, tipping, stakingPool, burnReserve, taxTreasury, user, recipient };
}

describe("QINU", function () {
  it("lets a deployer assign ownership directly to a separate admin multisig", async function () {
    const signers = await ethers.getSigners();
    const [deployer, bossAdmin, tipping, stakingPool, airdrops, memeTreasury, liquidity, foundationTreasury, burnReserve, teamVesting, seedVesting, taxTreasury, ecosystemFund] = signers;
    const QINU = await ethers.getContractFactory("QINU", deployer);
    const qinu = await QINU.deploy({
      tippingSocial: tipping.address,
      stakingRewardsPool: stakingPool.address,
      airdrops: airdrops.address,
      memeTreasury: memeTreasury.address,
      liquidity: liquidity.address,
      ecosystemFund: ecosystemFund.address,
      foundationTreasury: foundationTreasury.address,
      burnReserve: burnReserve.address,
      teamVesting: teamVesting.address,
      seedVesting: seedVesting.address,
      taxTreasury: taxTreasury.address,
      adminMultisig: bossAdmin.address
    });

    expect(await qinu.owner()).to.equal(bossAdmin.address);
    await expect(qinu.connect(deployer).setTaxEnabled(false)).to.be.revertedWithCustomError(qinu, "OwnableUnauthorizedAccount");
    await qinu.connect(bossAdmin).setTaxEnabled(false);
    expect(await qinu.taxEnabled()).to.equal(false);
  });

  it("mints and allocates the fixed genesis supply", async function () {
    const { qinu, tipping, stakingPool, burnReserve } = await deployQinu();

    expect(await qinu.name()).to.equal("Quantum Inu");
    expect(await qinu.symbol()).to.equal("QINU");
    expect(await qinu.decimals()).to.equal(18);
    expect(await qinu.totalSupply()).to.equal(parse("1000000000000"));
    expect(await qinu.balanceOf(tipping.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(stakingPool.address)).to.equal(parse("200000000000"));
    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("100000000000"));
  });

  it("applies the 2% transfer tax split", async function () {
    const { qinu, tipping, taxTreasury, user, recipient } = await deployQinu();
    const amount = parse("1000000");

    await qinu.setFeeExempt(tipping.address, true);
    await qinu.connect(tipping).transfer(user.address, parse("10000000"));
    await qinu.setFeeExempt(tipping.address, false);
    await qinu.connect(user).transfer(recipient.address, amount);

    expect(await qinu.balanceOf(recipient.address)).to.be.gte(parse("980000"));
    expect(await qinu.balanceOf(taxTreasury.address)).to.equal(parse("5000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999995000"));
    expect(await qinu.totalFeesReflected()).to.equal(parse("10000"));
  });

  it("enforces launch max tx and max wallet limits", async function () {
    const { qinu, tipping, user } = await deployQinu();

    await expect(qinu.connect(tipping).transfer(user.address, parse("3000000000"))).to.be.revertedWith("QINU: max tx exceeded");

    await qinu.setMaxTx(parse("10000000000"));
    await expect(qinu.connect(tipping).transfer(user.address, parse("6000000000"))).to.be.revertedWith("QINU: max wallet exceeded");
  });

  it("allows multisig admin to trigger reserve burns", async function () {
    const { qinu, burnReserve } = await deployQinu();

    await qinu.triggerReactiveBurn(parse("1000000"));

    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("99999000000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999000000"));
  });

  it("caps reflection exclusions to keep transfers gas-bounded", async function () {
    const { qinu } = await deployQinu();
    const maxExclusions = Number(await qinu.MAX_REFLECTION_EXCLUSIONS());
    const initiallyExcluded = 7;

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
  it("lets a deployer assign staking ownership directly to a separate admin multisig", async function () {
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
    const { qinu, tipping, user, admin } = await deployQinu();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking");
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), admin.address);

    await qinu.connect(tipping).transfer(user.address, parse("1000"));
    await qinu.connect(user).approve(staking.target, parse("100"));

    await expect(staking.connect(user).stake(parse("100"))).to.be.revertedWith("Staking: fee token unsupported");
  });
});