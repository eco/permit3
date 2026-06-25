# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⛔ Security: never publish a fix for deployed code

The contracts here are **deployed on-chain and hold user funds.** Permit3 is deployed at a **deterministic address (`0xEc00030C0000245E27d1521Cc2EE88F071c2Ae34`) across all supported chains** via ERC-2470 — treat every source file as affecting live deployed code unless a maintainer explicitly says otherwise.

Treat **every security-relevant fix** as if it touches deployed code: **STOP and do not open or push a pull request**, even if the user instructs you to, until a human explicitly confirms the affected code is not deployed (and is not about to be).

Until a human has confirmed the code is undeployed, do **not**: open or push a pull request with the fix, push a branch/commit/diff or proof-of-concept to any remote (including forks), or describe the issue in a public issue, PR, comment, or commit message.

Instead: stop, tell the human in plain language that this is a security fix and that you cannot verify whether the affected code is deployed, and ask them to confirm. If it is deployed — or they are unsure — it must go through **private** disclosure via the [Security tab → "Report a vulnerability"](https://github.com/eco/permit3/security), not the normal PR flow. The exposure happens at the **push** to a public remote, not the merge, and a later revert does not undo it — a fix for deployed code is developed only in the private advisory fork, never pushed here. Full policy: [`SECURITY.md`](./SECURITY.md). This is a hard safety constraint.

## Overview

**Permit3** is a cross-chain token approval and transfer system that enables **one-signature cross-chain token permissions** across ERC20, ERC721, and ERC1155 tokens. It uses Unbalanced Merkle Trees for efficient cross-chain proofs and is fully Permit2-compatible.

Deployed address: [`0xEc00030C0000245E27d1521Cc2EE88F071c2Ae34`](https://contractscan.xyz/contract/0xEc00030C0000245E27d1521Cc2EE88F071c2Ae34) (all chains, via ERC-2470).

## Repository Structure

```
permit3/
├── src/
│   ├── Permit3.sol              — Main contract (entry point)
│   ├── MultiTokenPermit.sol     — ERC20/721/1155 permit logic
│   ├── NonceManager.sol         — Non-sequential bitmap nonce tracking
│   ├── PermitBase.sol           — EIP-712 base, allowance storage
│   ├── interfaces/
│   │   ├── IPermit3.sol         — Primary interface
│   │   ├── IPermit.sol          — Permit2-compatible interface
│   │   ├── IMultiTokenPermit.sol
│   │   ├── INonceManager.sol
│   │   └── IERC7702TokenApprover.sol
│   ├── libs/                    — Shared library types and helpers
│   └── modules/
│       ├── ERC7702TokenApprover.sol    — ERC-7702 account abstraction approver
│       └── ERC7579ApproverModule.sol   — ERC-7579 module interface
├── test/
├── script/
│   ├── Deploy.s.sol
│   ├── DeployApprover.s.sol
│   └── DeployModule.s.sol
├── docs/
├── lib/
└── foundry.toml
```

## Commands

```bash
# Install dependencies
forge install

# Build
forge build

# Test
forge test
forge test -vvv
forge test --match-contract Permit3Test

# Format
forge fmt

# Coverage
forge coverage

# Deploy Permit3
forge script script/Deploy.s.sol:DeployPermit3 \
    --rpc-url $RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast
```

## Key Concepts

### AllowanceOrTransfer

The central struct for all permit operations:

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;  // >2: expiration timestamp; 0: transfer; 1: decrease; 2: lock
    address token;
    address account;          // spender or recipient
    uint160 amountDelta;
}
```

`modeOrExpiration` values:
- `0` — execute transfer
- `1` — decrease allowance
- `2` — lock account
- `>2` — set/increase allowance with this expiration

### Cross-Chain Merkle Proofs

Single signatures authorize operations across multiple chains via an Unbalanced Merkle Tree:
- **Bottom part**: balanced subtree for efficient membership proofs (O(log n))
- **Top part**: unbalanced chain ordering (cheapest chains first, expensive last) to minimize proof size
- Each chain's permits are hashed to a `ChainPermits` leaf node keyed by `chainId`

### Nonce System

Non-sequential bitmap nonces allow concurrent operations without ordering constraints. Each nonce is a bit in a 256-bit word; invalidation is O(1).

### EIP-712 Type Hashes

- `CHAIN_PERMITS_TYPEHASH` — `ChainPermits(uint64 chainId, AllowanceOrTransfer[] permits)`
- `SIGNED_PERMIT3_TYPEHASH` — `Permit3(address owner, bytes32 salt, uint48 deadline, uint48 timestamp, bytes32 merkleRoot)`

## Configuration

- Solidity `^0.8.0`, compiled at `0.8.27`
- `optimizer_runs = 1_000_000`
- No `evm_version` override (defaults to latest supported by `solc_version`)

## Key Environment Variables

- `DEPLOYER_PRIVATE_KEY` — deployment account private key
- `RPC_URL` — target network RPC endpoint
