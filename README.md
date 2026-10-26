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

`src/LiquidStaking.sol` (inherits from `ERC20`, `Ownable`, `ReentrancyGuard` and `Pausable`)

| Function                | What it does                                                 |
| ----------------------- | ------------------------------------------------------------ |
| `deposit()`             | Receives ETH and mints sETH proportional to the current rate |
| `withdraw(shares)`      | Burns sETH and returns ETH, rewards included                 |
| `exchangeRate()`        | Value of 1 sETH in ETH, with 18 decimals                     |
| `reportRewards()`       | Adds rewards to the pool (owner only)                        |
| `pause()` / `unpause()` | Stops or resumes deposits and withdrawals (owner only)       |

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
- **Reentrancy.** `nonReentrant` plus the checks-effects-interactions pattern: state is updated before ETH is sent.

### Verification

- **13 tests**, unit and fuzz (`test/LiquidStaking.t.sol`).
- **3 invariants** with a handler (`test/invariant/`), 256 runs and 128,000 calls per run:
  - the contract balance covers `totalPooledEth` (solvency);
  - the rate never drops below 1;
  - the supply equals the sum of all balances.
- **Mutation check.** Commenting out `totalPooledEth -= amount` in `withdraw` makes the solvency
