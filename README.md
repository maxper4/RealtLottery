# RealT Lottery Smart Contract

## Overview

This project is inspired by [PoolTogether](https://pooltogether.com), a no-loss lottery game. The main difference is that bidders provide [RealT](https://realt.co/) tokens. The prize is the rent collected from all the RealT tokens held by this contract. The winner is randomly selected from all the bidders. The winner gets the prize and all the bidders can get their RealT tokens back whenever they want.

## Randomness
This project uses Witnet as source of randomness: [Doc of witnet](https://docs.witnet.io/smart-contracts/witnet-randomness-oracle/generating-randomness).