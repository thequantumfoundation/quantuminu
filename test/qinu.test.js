const { expect } = require("chai");
const { ethers } = require("hardhat");

const parse = ethers.parseEther;
const MAINNET_CUSTODY_WALLET = "0x40ed2bf6557630e9184455da43a2df5149171b14";

async function deployQinu() {
  const signers = await ethers.getSigners();
  const [admin, tippingSocial, stakingRewardsPool, airdrops, memeTreasury, liquidity, ecosystemFund, foundationTreasury, burnReserve, team, publicSale, taxTreasury, user, recipient] = signers;

  const QINU = await ethers.getContractFactory("QINU");
  const qinu = await QINU.deploy(
    tippingSocial.address,
    stakingRewardsPool.address,
    airdrops.address,
    memeTreasury.address,
    liquidity.address,
    ecosystemFund.address,
    foundationTreasury.address,
    burnReserve.address,
    team.address,
    publicSale.address,
    taxTreasury.address,
    admin.address
  );

  return { qinu, signers, admin, tippingSocial, stakingRewardsPool, airdrops, memeTreasury, liquidity, ecosystemFund, foundationTreasury, burnReserve, team, publicSale, taxTreasury, user, recipient };
}

describe("QINU", function () {
  it("lets a deployer assign ownership directly to a separate admin wallet", async function () {
    const signers = await ethers.getSigners();
    const [deployer, bossAdmin, custodyWallet, taxTreasury] = signers;
    const QINU = await ethers.getContractFactory("QINU", deployer);
    const qinu = await QINU.deploy(
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      custodyWallet.address,
      taxTreasury.address,
      bossAdmin.address
    );

    expect(await qinu.owner()).to.equal(bossAdmin.address);
    expect(await qinu.balanceOf(custodyWallet.address)).to.equal(parse("1000000000000"));
    await expect(qinu.connect(deployer).setTaxEnabled(false)).to.be.revertedWithCustomError(qinu, "OwnableUnauthorizedAccount");
    await qinu.connect(bossAdmin).setTaxEnabled(false);
    expect(await qinu.taxEnabled()).to.equal(false);
  });

  it("mints the fixed supply according to the tokenomics allocation table", async function () {
    const { qinu, tippingSocial, stakingRewardsPool, airdrops, memeTreasury, liquidity, ecosystemFund, foundationTreasury, burnReserve, team, publicSale } = await deployQinu();

    expect(await qinu.name()).to.equal("Quantum Inu");
    expect(await qinu.symbol()).to.equal("QINU");
    expect(await qinu.decimals()).to.equal(18);
    expect(await qinu.totalSupply()).to.equal(parse("1000000000000"));
    expect(await qinu.balanceOf(tippingSocial.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(stakingRewardsPool.address)).to.equal(parse("200000000000"));
    expect(await qinu.balanceOf(airdrops.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(memeTreasury.address)).to.equal(parse("50000000000"));
    expect(await qinu.balanceOf(liquidity.address)).to.equal(parse("75000000000"));
    expect(await qinu.balanceOf(ecosystemFund.address)).to.equal(parse("75000000000"));
    expect(await qinu.balanceOf(foundationTreasury.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(team.address)).to.equal(parse("100000000000"));
    expect(await qinu.balanceOf(publicSale.address)).to.equal(parse("100000000000"));
  });

  it("supports the mainnet custody wallet while preserving allocation events", async function () {
    const [admin, taxTreasury] = await ethers.getSigners();
    const QINU = await ethers.getContractFactory("QINU");
    const qinu = await QINU.deploy(
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      MAINNET_CUSTODY_WALLET,
      taxTreasury.address,
      admin.address
    );

    expect(await qinu.balanceOf(MAINNET_CUSTODY_WALLET)).to.equal(await qinu.totalSupply());
  });

  it("applies the 2% transfer tax split", async function () {
    const { qinu, tippingSocial, taxTreasury, user, recipient } = await deployQinu();
    const amount = parse("1000000");

    await qinu.setFeeExempt(tippingSocial.address, true);
    await qinu.connect(tippingSocial).transfer(user.address, parse("10000000"));
    await qinu.setFeeExempt(tippingSocial.address, false);
    await qinu.connect(user).transfer(recipient.address, amount);

    expect(await qinu.balanceOf(recipient.address)).to.be.gte(parse("980000"));
    expect(await qinu.balanceOf(taxTreasury.address)).to.equal(parse("5000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999995000"));
    expect(await qinu.totalFeesReflected()).to.equal(parse("10000"));
  });

  it("enforces launch max tx and max wallet limits", async function () {
    const { qinu, tippingSocial, user, recipient } = await deployQinu();

    await qinu.setMaxWallet(parse("1000000000000"));
    await qinu.setLimitExempt(tippingSocial.address, true);
    await qinu.connect(tippingSocial).transfer(user.address, parse("3000000000"));
    await qinu.setLimitExempt(tippingSocial.address, false);
    await expect(qinu.connect(user).transfer(recipient.address, parse("3000000000"))).to.be.revertedWith("QINU: max tx exceeded");

    await qinu.setMaxTx(parse("10000000000"));
    await qinu.setMaxWallet(parse("5000000000"));
    await expect(qinu.connect(tippingSocial).transfer(recipient.address, parse("6000000000"))).to.be.revertedWith("QINU: max wallet exceeded");
  });

  it("allows admin to trigger reserve burns from the tokenomics burn reserve", async function () {
    const { qinu, burnReserve } = await deployQinu();

    await qinu.triggerReactiveBurn(parse("1000000"));

    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("99999000000"));
    expect(await qinu.totalSupply()).to.equal(parse("999999000000"));
  });

  it("does not count reactive burn volume for fee-exempt transfers", async function () {
    const { qinu, tippingSocial, user, recipient } = await deployQinu();

    await qinu.setMaxTx(parse("20000000000"));
    await qinu.setMaxWallet(parse("1000000000000"));
    await qinu.setFeeExempt(tippingSocial.address, true);

    await qinu.connect(tippingSocial).transfer(user.address, parse("10000000000"));

    expect(await qinu.reactiveBurnVolume()).to.equal(0);
    expect(await qinu.totalReactiveBurned()).to.equal(0);
  });

  it("automatically burns from the reserve for each 10B QINU moved between non-exempt users", async function () {
    const { qinu, tippingSocial, burnReserve, user, recipient } = await deployQinu();

    await qinu.setMaxTx(parse("20000000000"));
    await qinu.setMaxWallet(parse("1000000000000"));
    await qinu.setFeeExempt(tippingSocial.address, true);
    await qinu.connect(tippingSocial).transfer(user.address, parse("10000000000"));

    await expect(qinu.connect(user).transfer(recipient.address, parse("10000000000")))
      .to.emit(qinu, "ReactiveBurn")
      .withArgs(burnReserve.address, parse("1000000"));

    expect(await qinu.reactiveBurnVolume()).to.equal(0);
    expect(await qinu.totalReactiveBurned()).to.equal(parse("1000000"));
    expect(await qinu.balanceOf(burnReserve.address)).to.equal(parse("99999000000"));
    expect(await qinu.totalSupply()).to.equal(parse("999949000000"));
  });

  it("does not count admin or reserve transfers toward automatic reactive burns", async function () {
    const { qinu, burnReserve, user } = await deployQinu();

    await qinu.setMaxTx(parse("20000000000"));
    await qinu.setMaxWallet(parse("1000000000000"));

    await qinu.connect(burnReserve).transfer(user.address, parse("10000000000"));

    expect(await qinu.reactiveBurnVolume()).to.equal(0);
    expect(await qinu.totalReactiveBurned()).to.equal(0);
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
    const { qinu, tippingSocial, user, admin } = await deployQinu();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const lp = await MockERC20.deploy("QINU LP", "QLP");
    const Staking = await ethers.getContractFactory("QINUStaking");
    const staking = await Staking.deploy(qinu.target, lp.target, parse("1000000"), admin.address);

    await qinu.connect(tippingSocial).transfer(user.address, parse("1000"));
    await qinu.connect(user).approve(staking.target, parse("100"));

    await expect(staking.connect(user).stake(parse("100"))).to.be.revertedWith("Staking: fee token unsupported");
  });
});