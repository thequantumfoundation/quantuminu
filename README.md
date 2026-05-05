# Quantum Inu Contracts

This repository contains a QRC20/ERC20-compatible implementation for **Quantum Inu (QINU)** based on the final CTO build specification.

- Repository: `thequantumfoundation/quantuminu`
- Contact: `contact@thequantum.foundation`

## Token Summary

- Standard: QRC20-compatible ERC20 ABI
- Name: Quantum Inu
- Symbol: QINU
- Decimals: 18
- Initial supply: 1,000,000,000,000 QINU
- Minting: 100% minted at deploy, with no external mint function
- Supply: fixed and deflationary through burns
- Launch limits: 0.5% max wallet and 0.2% max transaction
- Transfer tax: 2% total
- Tax split: 1% reflection, 0.5% burn, 0.5% tax treasury
- Reactive burn: admin/multisig callable from the Burn Reserve wallet

## Contracts

- `QINU.sol`: core fixed-supply token with launch limits, configurable exemptions, burn-on-transfer, holder tiers, and reactive reserve burn.
- `QINUStaking.sol`: separate single-token and LP staking contract funded from the staking rewards allocation with a 3-year decaying emissions curve.
- `QINUVesting.sol`: separate linear vesting contract supporting team and seed schedules.
- `QINULPLock.sol`: simple LP token lock contract.

## Genesis Distribution

The `QINU` constructor accepts a `GenesisAddresses` struct and allocates the full 1T supply on deployment:

| Allocation                    | Amount |
| ----------------------------- | -----: |
| Tipping / Social              |    10% |
| Staking Rewards Pool          |    20% |
| Airdrops                      |    10% |
| Meme Treasury                 |     5% |
| Liquidity                     |   7.5% |
| Ecosystem Fund                |   7.5% |
| Treasury (Quantum Foundation) |    10% |
| Burn Reserve                  |    10% |
| Team Vesting                  |    10% |
| Seed Vesting                  |    10% |

The tax treasury is a separate address from the Quantum Foundation treasury and receives the 0.5% transfer treasury fee.

## Admin Model

Ownership is assigned at deployment to `adminMultisig`. Use your boss-controlled multisig address for this value, not the hot deployer wallet. The deployer pays gas, but should not become the production owner. The owner can:

- Configure fee and limit exemptions
- Configure max wallet and max transaction values
- Configure liquidity pairs
- Update the tax treasury
- Trigger reactive burns from the Burn Reserve wallet
- Optionally disable taxes, limits, or reflections after launch if the launch plan requires it

There is no DAO, no token ownership rights, no inflation, and no public minting function.

## Vesting Schedules

Deploy `QINUVesting` separately for each vesting bucket:

- Team: `duration = 4 * 365 days`, `cliffDuration = 365 days`
- Seed: `duration = 365 days`, `cliffDuration = 0`

Use the vesting contract addresses in the token genesis struct so their allocations are delivered at token deployment.

## Staking

Deploy `QINUStaking` after the token and LP token addresses are known. Fund it with the 20% staking rewards allocation. It supports:

- `stake(uint256)`
- `unstake(uint256)`
- `stakeLP(uint256)`
- `unstakeLP(uint256)`
- `claimRewards()`
- `pendingRewards(address)`
- `exit()`

## Setup

```bash
npm install
npm test
```

## Foundry / Forge

This repository also supports Forge builds through `foundry.toml`. OpenZeppelin Contracts is pinned as a Git submodule under `lib/openzeppelin-contracts`.

Install Foundry if needed:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Download Forge dependencies and compile:

```bash
npm run forge:install
npm run forge:build
```

Direct Forge commands work too:

```bash
git submodule update --init --recursive
forge build
```

## Repository Upload

Target GitHub repository:

```text
https://github.com/thequantumfoundation/quantuminu.git
```

Do not place GitHub passwords, personal access tokens, deployer private keys, mnemonics, or RPC secrets in this repository. Use GitHub CLI authentication, SSH keys, or a token through your credential manager.

```bash
git init
git branch -M main
git remote add origin https://github.com/thequantumfoundation/quantuminu.git
git add .
git commit -m "Initial QINU contracts"
git push -u origin main
```

If `origin` already exists, update it instead:

```bash
git remote set-url origin https://github.com/thequantumfoundation/quantuminu.git
```

## Deployment

Set environment variables for each genesis recipient before deployment:

```bash
export TIPPING_SOCIAL=0x...
export STAKING_REWARDS_POOL=0x...
export AIRDROPS=0x...
export MEME_TREASURY=0x...
export LIQUIDITY=0x...
export ECOSYSTEM_FUND=0x...
export FOUNDATION_TREASURY=0x...
export BURN_RESERVE=0x...
export TEAM_VESTING=0x...
export SEED_VESTING=0x...
export TAX_TREASURY=0x...
export ADMIN_MULTISIG=0x... # boss/multisig owner address, not the deployer wallet
npx hardhat run scripts/deploy.js --network <network>
```

The deploy script verifies that `owner()` is `ADMIN_MULTISIG` after deployment and refuses to deploy with the deployer as admin unless `ALLOW_DEPLOYER_ADMIN=true` is explicitly set.

If you intentionally deployed with your own wallet as a temporary owner, transfer ownership to your boss/multisig immediately:

```bash
export CONTRACT_ADDRESS=0x...          # QINU or another Ownable contract
export NEW_ADMIN_MULTISIG=0x...        # boss/multisig owner address
npm run transfer-admin -- --network <network>
```

For multiple Ownable contracts, such as QINU and QINUStaking, use a comma-separated list:

```bash
export CONTRACT_ADDRESSES=0xQINU...,0xSTAKING...
export NEW_ADMIN_MULTISIG=0x...
npm run transfer-admin -- --network <network>
```

Add the target Qtum/QRC20 network settings to `hardhat.config.js` before live deployment.
