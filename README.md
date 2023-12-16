# Safe Anonymization Module

## Description

This is an implementation of the PoC contract for the Safe Wallet grant.

Our key concept is centered around the creation of a module for Safe multisig that ensures the anonymity of all its participants using ZK-SNARK technology.

The details are described in:

- [Proposal](https://oxorioteam.notion.site/Safe-Anonymization-Module-proposal-efe966603632482abf243283bfc78897)
- [Research](https://oxorioteam.notion.site/Safe-Anonymization-Module-1-M-1e702d426bfd46a4aa89b463d2b81d2c)

## Requirements

- Foundry

## Installation

To get started with this project, you need to install Foundry. Follow the instructions [here](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone https://github.com/oxor-io/sam-contracts.git
cd sam-contracts
foundryup
forge install
```

## Testing

Before running tests, you will need to set up an `.env` file in the project root with an Ethereum API key. Create a `.env` file and add the following:

```
MAINNET_RPC={your-ethereum-api-key}
```

Replace `your-ethereum-api-key` with your actual API key. Then, you can run tests with the following command:

```bash
forge test
```

## Proof generation

For detailed instructions on how to generate a proof, refer to the repository with [circuit](https://github.com/oxor-io/sam-circuits).

## Disclaimer

The code provided in this repository has not undergone a security audit. It is provided "as is" and without any warranty.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
