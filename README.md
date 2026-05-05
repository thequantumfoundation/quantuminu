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
- Minting: 100% minted at deploy through explicit tokenomics allocation buckets, with no external mint function
- Supply: fixed and deflationary through burns
- Launch limits: 0.5% max wallet and 0.2% max transaction
- Transfer tax: 2% total
- Tax split: 1% reflection, 0.5% burn, 0.5% tax treasury
- Reactive burn: every 10B QINU traded or tipped burns 1M QINU from the Burn Reserve wallet

## Contracts

- `QINU.sol`: core fixed-supply token with launch limits, configurable exemptions, burn-on-transfer, holder tiers, and automatic reactive reserve burn.
- `QINUStaking.sol`: separate single-token and LP staking contract funded from the staking rewards allocation with a 3-year decaying emissions curve.
- `QINULPLock.sol`: optional LP token timelock. The admin wallet may also simply hold LP directly.

## Genesis Minting

The `QINU` constructor accepts direct address fields for each tokenomics allocation bucket and mints the full 1T supply according to the tokenomics paper on deployment.

Each allocation emits a `GenesisAllocation` event with the category, recipient, and amount. If a single custody wallet will manage distribution operationally, use that same wallet for the allocation recipient fields. The on-chain events still show the paper allocation buckets.

The allocation recipients are intentionally separate from the admin owner. The tax treasury is also a separate address and receives the 0.5% transfer treasury fee.

Manual deploy tools such as Remix should show these constructor fields separately:

```text
tippingSocial       = 0x40ed2bf6557630e9184455da43a2df5149171b14
stakingRewardsPool  = 0x40ed2bf6557630e9184455da43a2df5149171b14
airdrops            = 0x40ed2bf6557630e9184455da43a2df5149171b14
memeTreasury        = 0x40ed2bf6557630e9184455da43a2df5149171b14
liquidity           = 0x40ed2bf6557630e9184455da43a2df5149171b14
ecosystemFund       = 0x40ed2bf6557630e9184455da43a2df5149171b14
foundationTreasury  = 0x40ed2bf6557630e9184455da43a2df5149171b14
burnReserve_        = 0x40ed2bf6557630e9184455da43a2df5149171b14
team                = 0x40ed2bf6557630e9184455da43a2df5149171b14
publicSale          = 0x40ed2bf6557630e9184455da43a2df5149171b14
taxTreasury         = 0x...
adminOwner          = 0x...
```

## Admin Model

Ownership is assigned at deployment to `adminOwner`. This can be a normal wallet or a multisig. Use your boss-controlled admin wallet for this value, not the hot deployer wallet. The deployer pays gas, but should not become the production owner. The owner can:

- Configure fee and limit exemptions
- Configure max wallet and max transaction values
- Configure limit exemptions for liquidity pools, routers, and operational wallets
- Configure reactive burn exemptions for admin, reserve, or operational wallets
- Update the tax treasury
- Trigger manual reserve burns if needed
- Optionally disable taxes, limits, or reflections after launch if the launch plan requires it

There is no DAO, no token ownership rights, no inflation, and no public minting function.

## Staking

Deploy `QINUStaking` after the token and LP token addresses are known. Fund it from the staking rewards allocation wallet or another wallet approved by the admin owner. It supports:

- `stake(uint256)`
- `unstake(uint256)`
- `stakeLP(uint256)`
- `unstakeLP(uint256)`
- `claimRewards()`
- `pendingRewards(address)`
- `exit()`

## Reactive Burn

Automatic reactive burn tracking is **always active** and cannot be disabled. The token tracks transfer volume between non-exempt accounts. The genesis allocation wallets, admin owner, tax treasury, burn reserve, token contract, and burn address are exempt by default so admin, reserve, treasury, and allocation operations do not accidentally trigger reactive burns.

The owner can update this list if needed:

```text
setReactiveBurnExempt(0xWalletAddress, true)
setReactiveBurnExempt(0xWalletAddress, false)
```

- For every `10,000,000,000 QINU` counted, the contract burns `1,000,000 QINU` from `burnReserve`.
- The counter remainder is kept in `reactiveBurnVolume()` until the next threshold is reached.
- `totalReactiveBurned()` tracks reserve burns made through the reactive burn functions.

Manual reserve burns remain available to the owner:

```text
triggerReactiveBurn(amount)
```

For liquidity setup, there is no special pair registry. If a pool or router must bypass launch wallet limits, use the normal limit exemption function:

```text
setLimitExempt(0xPoolOrRouterAddress, true)
```

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

Set environment variables before deployment:

```bash
export TIPPING_SOCIAL=0x40ed2bf6557630e9184455da43a2df5149171b14
export STAKING_REWARDS_POOL=0x40ed2bf6557630e9184455da43a2df5149171b14
export AIRDROPS=0x40ed2bf6557630e9184455da43a2df5149171b14
export MEME_TREASURY=0x40ed2bf6557630e9184455da43a2df5149171b14
export LIQUIDITY=0x40ed2bf6557630e9184455da43a2df5149171b14
export ECOSYSTEM_FUND=0x40ed2bf6557630e9184455da43a2df5149171b14
export FOUNDATION_TREASURY=0x40ed2bf6557630e9184455da43a2df5149171b14
export BURN_RESERVE=0x40ed2bf6557630e9184455da43a2df5149171b14
export TEAM=0x40ed2bf6557630e9184455da43a2df5149171b14
export PUBLIC_SALE=0x40ed2bf6557630e9184455da43a2df5149171b14
export TAX_TREASURY=0x...
export ADMIN_OWNER=0x... # boss/admin wallet, not the deployer wallet
npx hardhat run scripts/deploy.js --network <network>
```

The deploy script verifies that `owner()` is `ADMIN_OWNER` after deployment. It refuses to deploy with the deployer as admin unless `ALLOW_DEPLOYER_ADMIN=true` is explicitly set.

If you intentionally deployed with your own wallet as a temporary owner, transfer ownership to your boss/admin wallet immediately:

```bash
export CONTRACT_ADDRESS=0x...          # QINU or another Ownable contract
export NEW_ADMIN_OWNER=0x...           # boss/admin wallet address
npm run transfer-admin -- --network <network>
```

For multiple Ownable contracts, such as QINU and QINUStaking, use a comma-separated list:

```bash
export CONTRACT_ADDRESSES=0xQINU...,0xSTAKING...
export NEW_ADMIN_OWNER=0x...
npm run transfer-admin -- --network <network>
```

Add the target Qtum/QRC20 network settings to `hardhat.config.js` before live deployment.
