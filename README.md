# cloak  • [![tests](https://github.com/abigger87/cloak/actions/workflows/tests.yml/badge.svg)](https://github.com/abigger87/cloak/actions/workflows/tests.yml) [![lints](https://github.com/abigger87/cloak/actions/workflows/lints.yml/badge.svg)](https://github.com/abigger87/cloak/actions/workflows/lints.yml) ![GitHub](https://img.shields.io/github/license/abigger87/cloak) ![GitHub package.json version](https://img.shields.io/github/package-json/v/abigger87/cloak)

**Extensible** ERC721 with a Built-in Commit-Reveal Scheme.

## Overview

Mints suck...

They're difficult to mint, oft impossible.
The mint price is fixed - artists and creators don't realize upside.

Is this fixable?

Honestly, not without tradeoffs.

Cloaks sacrifices ordering (first-come first-serve) for price-discovery and gas efficiency.

_How_ does this work?

When a mint process begins, cloaks enables a commit session, that lasts for an arbitrarily long period to prevent gas wars. During the commit session, users can `commit()` a hidden price they value the ERC721 at.



///// TODO

Users must provide a deposit (of amount `minPrice`) to `commit()` in a mint.

If a user gets an allocation for their price and forgo a mint, they suffer a penalty
on their deposit proportional to how close the `resultPrice` is to their `providedPrice`.




## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
├─ clones-with-immutable-args — https://github.com/wighawag/clones-with-immutable-args
src
├─ tests
│  └─ Cloak.t — "Cloak Tests"
└─ Cloak — "The main Cloak contract"
```

## Development

[Cloak](https://github.com/abigger87/cloak) is an extensible ERC721 implementation with a commit-reveal scheme built _into_ the ERC721 contract itself.
The only contract is located in [src/](./src/) called [Cloak](./src/Cloak.sol).

Both [DappTools](https://dapp.tools/) and [Foundry](https://github.com/gaskonst/foundry) are supported. Installation instructions for both are included below.

#### Install DappTools

Install DappTools using their [installation guide](https://github.com/dapphub/dapptools#installation).

#### First time with Forge/Foundry?

See the official Foundry installation [instructions](https://github.com/gakonst/foundry/blob/master/README.md#installation).

Don't have [rust](https://www.rust-lang.org/tools/install) installed?
Run
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then, install the [foundry](https://github.com/gakonst/foundry) toolchain installer (`foundryup`) with:
```bash
curl -L https://foundry.paradigm.xyz | bash
```

Now that you've installed the `foundryup` binary,
anytime you need to get the latest `forge` or `cast` binaries,
you can run `foundryup`.

So, simply execute:
```bash
foundryup
```

🎉 Foundry is installed! 🎉

#### Setup

```bash
make
# OR #
make setup
```

#### Build

```bash
make build
```

#### Run Tests

```bash
make test
```

#### Configure Foundry

Using [foundry.toml](./foundry.toml), Foundry is easily configurable.

## License

[AGPL-3.0-only](https://github.com/abigger87/cloak/blob/master/LICENSE)

# Acknowledgements

- [commit-reveal schemes](https://medium.com/swlh/exploring-commit-reveal-schemes-on-ethereum-c4ff5a777db8)
- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [clones-with-immutable-args](https://github.com/wighawag/clones-with-immutable-args).
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).
- [forge-template](https://github.com/FrankieIsLost/forge-template) by [FrankieIsLost](https://github.com/FrankieIsLost).
- [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource.

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
