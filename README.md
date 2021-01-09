# DecentCoder

DecentCoder is the first fully-decentralized programming contest platform on Ethereum.

It is still under development and has not yet been deployed on mainnet or testnet.

## Requirement

+ [Truffle](https://github.com/trufflesuite/truffle)
+ [Ganache](https://github.com/trufflesuite/ganache) to run a private network for development

## Backend (Truffle project)

### Directory structure

```
.
├── contracts (Solidity code of contracts)
├── migrations (JavaScript code to deploy contracts to a network)
├── test (JavaScript and Solidity code to test contracts)
└── truffle-config.js (Truffle project configuration)
```

### Compiles and deploys for development

1. Start Ganache
2. Run `truffle migrate`

### Tests contracts

Run `truffle test`

### Customize configuration

See [Configuration Reference](https://www.trufflesuite.com/docs/truffle/reference/configuration).

## Frontend (Vue project)

### Project setup

Run `npm install`

### Compiles and hot-reloads for development

Run `npm run serve`

<!--
### Compiles and minifies for production

Run `npm run build`
-->

### Lints and fixes files

Run `npm run lint`

### Customize configuration

See [Configuration Reference](https://cli.vuejs.org/config/).
