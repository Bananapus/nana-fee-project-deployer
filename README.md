# Bananapus Fee Project Deployer

Deploys the Bananapus project with project ID #1, which receives Juicebox ecosystem fees.

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#usage">Usage</a></li>
  <ul>
    <li><a href="#install">Install</a></li>
    <li><a href="#develop">Develop</a></li>
    <li><a href="#scripts">Scripts</a></li>
    <li><a href="#deployments">Deployments</a></li>
    <ul>
      <li><a href="#with-sphinx">With Sphinx</a></li>
      <li><a href="#without-sphinx">Without Sphinx</a></li>
      </ul>
    <li><a href="#tips">Tips</a></li>
    </ul>
    <li><a href="#repository-layout">Repository Layout</a></li>
    <li><a href="#description">Description</a></li>
  <ul>
    <li><a href="#how-fees-work">How Fees Work</a></li>
    <li><a href="#project-description">Project Description</a></li>
    </ul>
  </ul>
  </ol>
</details>

_If you're having trouble understanding this contract, take a look at the [core protocol contracts](https://github.com/Bananapus/nana-core) and the [documentation](https://docs.juicebox.money/) first. If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS)._

## Usage

### Install

How to install `nana-fee-project-deployer` in another project.

For projects using `npm` to manage dependencies (recommended):

```bash
npm install @bananapus/fee-project-deployer
```

For projects using `forge` to manage dependencies (not recommended):

```bash
forge install Bananapus/nana-fee-project-deployer
```

If you're using `forge` to manage dependencies, add `@bananapus/fee-project-deployer/=lib/nana-fee-project-deployer/` to `remappings.txt`. You'll also need to install `nana-fee-project-deployer`'s dependencies and add similar remappings for them.

### Develop

`nana-fee-project-deployer` uses [npm](https://www.npmjs.com/) (version >=20.0.0) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm ci && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

### Scripts

For convenience, several utility commands are available in `package.json`.

| Command             | Description                                             |
| ------------------- | ------------------------------------------------------- |
| `npm run artifacts` | Fetch Sphinx artifacts and write them to `deployments/` |

### Deployments

#### With Sphinx

`nana-fee-project-deployer` manages deployments with [Sphinx](https://www.sphinx.dev). To run the deployment scripts, install the npm `devDependencies` with:

```bash
`npm ci --also=dev`
```

You'll also need to set up a `.env` file based on `.example.env`. Then run one of the following commands:

| Command                   | Description                  |
| ------------------------- | ---------------------------- |
| `npm run deploy:mainnets` | Propose mainnet deployments. |
| `npm run deploy:testnets` | Propose testnet deployments. |

Your teammates can review and approve the proposed deployments in the Sphinx UI. Once approved, the deployments will be executed.

#### Without Sphinx

You can use the Sphinx CLI to run the deployment scripts without paying for Sphinx. First, install the npm `devDependencies` with:

```bash
`npm ci --also=dev`
```

You can deploy the contracts like so:

```bash
PRIVATE_KEY="0x123..." RPC_ETHEREUM_SEPOLIA="https://rpc.ankr.com/eth_sepolia" npx sphinx deploy script/Deploy.s.sol --network ethereum_sepolia
```

This example deploys `nana-fee-project-deployer` to the Sepolia testnet using the specified private key. You can configure new networks in `foundry.toml`.

### Tips

To view test coverage, run `npm run coverage` to generate an LCOV test report. You can use an extension like [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) to view coverage in your editor.

If you're using Nomic Foundation's [Solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) extension in VSCode, you may run into LSP errors because the extension cannot find dependencies outside of `lib`. You can often fix this by running:

```bash
forge remappings >> remappings.txt
```

This makes the extension aware of default remappings.

## Repository Layout

The root directory contains this README, an MIT license, and config files. If you're developing, you're probably looking for one of these directories:

```
fee-project-deployer/
├── .github/
│   └── workflows/ - CI/CD workflows
└── script/
    └── Deploy.s.sol - Fee project deployment script
```

## Description

### How Fees Work

Project ID #1 receives Juicebox ecosystem fees. For example, see [`JBMultiTerminal._FEE_BENEFICIARY_PROJECT_ID`](https://github.com/Bananapus/nana-core/blob/main/src/JBMultiTerminal.sol#L86):

```solidity
/// @notice Project ID #1 receives fees. It should be the first project launched during the deployment process.
uint256 internal constant _FEE_BENEFICIARY_PROJECT_ID = 1;
```

This ID is referenced in [`JBMultiTerminal.executeProcessFee(…)`](https://github.com/Bananapus/nana-core/blob/main/src/JBMultiTerminal.sol#L576). Note that this is done by convention – in theory, someone could launch a terminal which pays fees to a different project, or doesn't pay fees at all.

### Project Description

The project deployed by `nana-fee-project-deployer` is not a vanilla Juicebox project:

- The fee project is deployed to Ethereum mainnet and Optimism mainnet.
- The fee project is deployed with two terminals.
    - A [`JBMultiTerminal`](https://github.com/Bananapus/nana-core/blob/main/src/JBMultiTerminal.sol) which accepts payments in `JBConstants.NATIVE_TOKEN` – the native token on each network.
    - A [`JBSwapTerminal`](https://github.com/Bananapus/nana-swap-terminal/blob/main/src/JBSwapTerminal.sol) which accepts any other token and swaps it for the `JBConstants.NATIVE_TOKEN`.
- The fee project is a [Revnet](https://github.com/rev-net/revnet-core).
    - The initial split operator is the `OPERATOR` address, which is hard-coded to `0x961d4191965C49537c88F764D88318872CE405bE`.
    - It pre-mints 37,000,000 tokens to the `OPERATOR` address on Optimism.
    - Its first stage starts 24 hours after the deployment.
    - It has a 20% split rate (reserved rate in standard Juicebox terminology).
    - Its initial issuance rate is 1,000 tokens per native token.
    - Every 7 days, this issuance rate decays by 1%.
    - The price floor tax intensity is 0.3.
- The fee project is deployed with a [buyback hook](https://github.com/Bananapus/nana-buyback-hook). It buys from the 1% fee Uniswap v3 pool between $NANA (the project's token) and the (wrapped) native token on each network.
- The fee project can mint tiered ERC-721 tokens via the [CropTop publisher](https://github.com/rev-net/revnet-core/blob/main/src/REVCroptopDeployer.sol). It launches with 6 pre-configured tiers.
- The fee project supports cross-chain bridging via [`nana-suckers`](https://github.com/Bananapus/nana-suckers). At launch, it maps between each network's native token to the other.
    
