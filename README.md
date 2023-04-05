<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./.github/img/fenix-dark.svg">
  <img alt="fenix" src="./.github/img/fenix-light.svg">
</picture>
<br>
FENIX pays you to hold your own crypto

</p>
<p align="center">
  <a href="https://github.com/atomizexyz/fenix/actions"><img src="https://img.shields.io/github/actions/workflow/status/atomizexyz/fenix/ci.yml?branch=main&style=flat-square"/></a>
  <a href="https://getfoundry.sh/"><img src="https://img.shields.io/badge/built%20with-Foundry-FFDB1C.svg?style=flat-square"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square"/></a>
</p>

## Introduction

FENIX is designed to reward crypto community members who believe in cryptos first principles of self-custody,
transparency, trust through consensus, and permissionless value exchange without counterparty risk.

## Links

- [https://fenix.fyi](https://fenix.fyi) - Official website
- [https://atomize.xyz/fenix](https://atomize.xyz/fenix) - Landing page
- [Litepaper](https://github.com/atomizexyz/litepaper) - Smart contract litepaper
- [Documentation](https://docs.atomize.xyz) - FENIX documentation

## Build

**Clone** - Clone the smart contract to your local machine

```sh
git clone http://github.com/atomizexyz/fenix
```

**Clean** — Clean the build

```sh
forge clean
```

**Build** — Build the smart contract for deployment and testing

```sh
forge build
```

**Test** — Run unit tests

```sh
forge test
```

**Lint** — Lint code

```sh
yarn lint
```

## Gas Report

| src/Fenix.sol:Fenix contract |                 |        |        |        |         |
| ---------------------------- | --------------- | ------ | ------ | ------ | ------- |
| Deployment Cost              | Deployment Size |        |        |        |         |
| 2866891                      | 14437           |        |        |        |         |
| Function Name                | min             | avg    | median | max    | # calls |
| MAX_STAKE_LENGTH_DAYS        | 262             | 262    | 262    | 262    | 5       |
| XEN_BURN_RATIO               | 285             | 285    | 285    | 285    | 1       |
| balanceOf                    | 584             | 1397   | 584    | 2584   | 86      |
| burnXEN                      | 17690           | 60511  | 45050  | 96010  | 133     |
| calculateBonus               | 10820           | 11004  | 11047  | 11103  | 4       |
| calculateEarlyPayout         | 1117            | 2170   | 2589   | 2589   | 7       |
| calculateLatePayout          | 1095            | 1884   | 2428   | 2428   | 7       |
| calculateShares              | 2858            | 2858   | 2858   | 2858   | 1       |
| calculateSizeBonus           | 452             | 452    | 452    | 452    | 1       |
| calculateTimeBonus           | 920             | 920    | 920    | 920    | 1       |
| cooldownUnlockTs             | 362             | 362    | 362    | 362    | 2       |
| decimals                     | 289             | 289    | 289    | 289    | 1       |
| deferStake                   | 1755            | 18260  | 22964  | 22980  | 9       |
| endStake                     | 2587            | 29474  | 29887  | 33126  | 58      |
| equityPoolSupply             | 385             | 718    | 385    | 2385   | 12      |
| flushRewardPool              | 372             | 19146  | 27033  | 29033  | 6       |
| name                         | 3243            | 3243   | 3243   | 3243   | 1       |
| onTokenBurned                | 502             | 38892  | 26757  | 68557  | 136     |
| rewardPoolSupply             | 362             | 1695   | 2362   | 2362   | 3       |
| shareRate                    | 405             | 405    | 405    | 405    | 2       |
| stakeCount                   | 581             | 581    | 581    | 581    | 7       |
| stakeFor                     | 1960            | 1960   | 1960   | 1960   | 12      |
| startStake                   | 393             | 122735 | 121765 | 162177 | 73      |
| supportsInterface            | 357             | 357    | 357    | 357    | 133     |
| symbol                       | 3263            | 3263   | 3263   | 3263   | 1       |
| totalSupply                  | 360             | 1360   | 1360   | 2360   | 4       |

## Deployment Checklist

#### Mainnet XEN Address List

| Chain        | Contract Address                             |
| :----------- | :------------------------------------------- |
| Ethereum     | `0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8` |
| BNB          | `0x2AB0e9e4eE70FFf1fB9D67031E44F6410170d00e` |
| Polygon      | `0x2AB0e9e4eE70FFf1fB9D67031E44F6410170d00e` |
| Avalanche    | `0xC0C5AA69Dbe4d6DDdfBc89c0957686ec60F24389` |
| Ethereum PoW | `0x2AB0e9e4eE70FFf1fB9D67031E44F6410170d00e` |
| Moonbeam     | `0xb564A5767A00Ee9075cAC561c427643286F8F4E1` |
| Evmos        | `0x2AB0e9e4eE70FFf1fB9D67031E44F6410170d00e` |
| Fantom       | `0xeF4B763385838FfFc708000f884026B8c0434275` |
| Dogechain    | `0x948eed4490833D526688fD1E5Ba0b9B35CD2c32e` |
| OKCChain     | `0x1cC4D981e897A3D2E7785093A648c0a75fAd0453` |

#### Deployment Scripts

- [ ] Update address in Fenix.sol to point to XEN contract address
- [ ] Run `./script/deployProdFENIX.sh`

```sh
# EIP-1559
forge script script/FenixProd.s.sol:FenixProdScript --rpc-url $RPC_URL

# NON EIP-1559
forge script script/FenixProd.s.sol:FenixProdScript --rpc-url $RPC_URL --legacy
```

```
forge script script/FENIXProd.s.sol:FENIXProdScript --rpc-url $GOERLI_RPC_URL --broadcast -vvvv
forge script script/FENIXProd.s.sol:FENIXProdScript --rpc-url $MUMBAI_RPC_URL --broadcast -vvvv
forge script script/FENIXProd.s.sol:FENIXProdScript --rpc-url $X1_RPC_URL --legacy --broadcast -vvvv
```

## Acknowledgements

- [Bitcoin](https://github.com/bitcoin/bitcoin) (Jan 8, 2009) — Censorship resistant zero counter party risk value
  storage and transfer
- [`0x1f98...f984`](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984)
  [Uniswap V1](https://github.com/Uniswap/v1-contracts) (Nov 2, 2018) — Equity based liquidity pool
- [`0xd9D4...F5a6`](https://etherscan.io/token/0xd9D4A7CA154fe137c808F7EEDBe24b639B7AF5a6)
  [Cereneum](https://github.com/Cereneum/Cereneum) (Jun 6, 2019) — Time-based interest-bearing Cryptographic Certificate
  of Interest
- [`0x2b59...eb39`](https://etherscan.io/token/0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39)
  [HEX](https://github.com/BitcoinHEX/contract) (Dec 2, 2019) — Share rate ratcheting increasing the cost basis for
  later stakers

- [`0x0645...6Fb8`](https://etherscan.io/token/0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8)
  [XEN Crypto](https://github.com/FairCrypto/XEN-crypto) (Oct 8, 2022) — Cross-chain protocol launch
