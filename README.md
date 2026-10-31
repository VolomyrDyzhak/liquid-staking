# Marea · Liquid Staking in Solidity

[![CI](https://github.com/VolomyrDyzhak/liquid-staking/actions/workflows/test.yml/badge.svg)](https://github.com/VolomyrDyzhak/liquid-staking/actions/workflows/test.yml)

🇪🇸 [Leer en español](README.es.md)

A simplified liquid staking protocol built with Foundry and OpenZeppelin as a portfolio project. Users deposit ETH and receive **sETH**, a token whose value in ETH grows as rewards arrive. It follows the _shares and exchange rate_ model used by protocols such as Rocket Pool (rETH) and Lido's wstETH.

> **Disclaimer:** educational project, not professionally audited. Do not use with real funds.

## How it works

The contract tracks `totalPooledEth` (the ETH backing all tokens) and the sETH `totalSupply`. The value of one token is:

```
exchangeRate = totalPooledEth / totalSupply
```

Example:

| Step                     | Pool (ETH) | sETH minted | Rate |
| ------------------------ | ---------- | ----------- | ---- |
| Alice deposits 10 ETH    | 10         | 10          | 1.0  |
| 1 ETH of rewards arrives | 11         | 10          | 1.1  |
| Bob deposits 11 ETH      | 22         | 20          | 1.1  |
| Alice withdraws 10 sETH  | 11         | 10          | 1.1  |

Alice receives 11 ETH: her deposit plus the rewards. Bob received 10 sETH for his 11 ETH, because each token was already worth more.

`totalPooledEth` is internal accounting and never reads `address(this).balance`, so sending ETH directly to the contract does not change the rate.

## Contract

`src/LiquidStaking.sol` (inherits from `ERC20`, `AccessControl`, `ReentrancyGuard` and `Pausable`)

| Function                | What it does                                                   |
| ----------------------- | -------------------------------------------------------------- |
| `deposit()`             | Receives ETH and mints sETH proportional to the current rate   |
| `withdraw(shares)`      | Burns sETH and returns ETH, rewards included                   |
| `exchangeRate()`        | Value of 1 sETH in ETH, with 18 decimals                       |
| `reportRewards()`       | Adds rewards to the pool (`ORACLE_ROLE` only)                  |
| `pause()` / `unpause()` | Stops or resumes deposits and withdrawals (`PAUSER_ROLE` only) |

Access control uses OpenZeppelin `AccessControl`. The admin only grants and revokes roles and does **not** receive the oracle or pauser roles at deployment.

## Run the project

Requirements: [Foundry](https://book.getfoundry.sh/).

```bash
git clone --recurse-submodules https://github.com/VolomyrDyzhak/liquid-staking.git
cd liquid-staking
forge build
forge test -vv
```

## Security

### Findings and decisions

- **Rounding to zero shares.** With a high exchange rate, a small deposit could mint 0 shares and its ETH stayed in the pool. Reproduced first with two failing tests, then fixed with `require(shares > 0)`. The commit history keeps that order: failing test, then fix.
- **Emergency pause.** `Pausable` on deposits and withdrawals. Pausing withdrawals too protects the system but locks user funds for the duration of the pause; many protocols pause deposits only. This is a deliberate choice to practice the full mechanism.
- **Role separation.** Rewards can only be reported by `ORACLE_ROLE` and pausing requires `PAUSER_ROLE`, so no single account holds every power by default.
- **Reentrancy.** `nonReentrant` plus the checks-effects-interactions pattern: state is updated before ETH is sent.

### Verification

- **22 tests**: 13 unit and fuzz (`test/LiquidStaking.t.sol`), 8 role-permission tests including negative cases (`test/LiquidStakingRoles.t.sol`), and 1 invariant suite with 3 properties.
- **3 invariants** with a handler (`test/invariant/`), 256 runs and 128,000 calls per run:
  - the contract balance covers `totalPooledEth` (solvency);
  - the rate never drops below 1;
  - the supply equals the sum of all balances.
- **Mutation check.** Commenting out `totalPooledEth -= amount` in `withdraw` makes the solvency invariant fail, which shows the invariants catch real bugs.
- **Slither** (102 detectors): 0 results. There is one `low-level-calls` warning in `withdraw`, suppressed on purpose: `call` is used instead of `transfer` (2300 gas limit) and is protected by `nonReentrant`. Report in [`reports/slither-report.txt`](reports/slither-report.txt).
- **CI** on GitHub Actions: checks formatting (`forge fmt --check`) and runs `forge test` on every push.

### Known limitations

- Rewards are reported by a single `ORACLE_ROLE` address, which is still a trusted party, and the admin can grant itself any role. In production the admin would be a multisig with a timelock and the oracle a decentralized network.
- There are no real validators or withdrawal queue: the ETH sits inside the contract.
- The pauser can freeze withdrawals, which is a centralization risk.

## Structure

```
src/                  main contract
test/                 unit, fuzz and role tests
test/invariant/       invariant tests
test/handlers/        handler that guides the fuzzer
reports/              Slither report
```

## Status and roadmap

- [x] Base contract with unit and fuzz tests
- [x] Rounding fix, emergency pause, invariants and Slither
- [x] Separate roles for the rewards oracle and the pauser (`AccessControl`)
- [ ] Withdrawal queue with simulated validators
- [ ] Deployment and verification on Sepolia
- [ ] Frontend with Next.js, wagmi and viem

An [interactive demo of the concept](https://claude.ai/artifact/43fQoyEe3TSnNJWNXZkFy5) simulates the logic in the browser, without a blockchain.

## Live deployment (Sepolia testnet)

|          |                                                                                                                                                              |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Network  | Ethereum Sepolia (chain ID 11155111)                                                                                                                         |
| Contract | [`0x11D69a0bd1C700a4d9F8527A41BC7a86e504c680`](https://sepolia.etherscan.io/address/0x11D69a0bd1C700a4d9F8527A41BC7a86e504c680#code) (verified on Etherscan) |
| Roles    | One deployer account holds admin, pauser and oracle (testnet demo)                                                                                           |

Rewards are simulated: an oracle account reports them manually. Testnet ETH has no value.

**Deployment note:** deployed with `forge create`. After Sepolia's Glamsterdam upgrade (October 2026), `forge script` failed with out-of-gas because Foundry's local simulation underestimated contract creation costs; letting the node estimate gas fixed it.

## Contact

Volomyr Dyzhak · [GitHub](https://github.com/VolomyrDyzhak) · volodymyrdyzhak@gmail.com
