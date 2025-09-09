# 🔏 Permit3 Core Concepts 🏗️

🧭 [Home](/docs/README.md) > Concepts

This section provides in-depth explanations of the core concepts behind Permit3.

## 📚 Available Documentation

| Document | Description |
|----------|-------------|
| [🏛️ Architecture](./architecture.md) | Overview of the Permit3 system architecture and components |
| [🧩 Witness Functionality](./witness-functionality.md) | Detailed explanation of witness functionality and its use cases |
| [🌉 Cross-Chain Operations](./cross-chain-operations.md) | How Permit3 enables operations across multiple blockchains |
| [🌲 Unbalanced Merkle Trees](./unbalanced-merkle-tree.md) | Understanding the cryptographic structure enabling efficient cross-chain proofs |
| [🔢 Nonce Management](./nonce-management.md) | Permit3's approach to nonce handling for replay protection |
| [🔁 Allowance System](./allowance-system.md) | Understanding the flexible allowance system in Permit3 |
| [🎨 Multi-Token Support](./multi-token-support.md) | NFT and semi-fungible token support with dual-allowance system |

## 🧱 Core Components

Permit3 consists of three main components:

1. 📄 **Permit3 Contract**: Main contract implementing cross-chain token approvals and transfers
2. 📑 **PermitBase Contract**: Handles token approvals and transfers
3. 🧮 **NonceManager Contract**: Provides nonce management for replay protection

These components work together to provide a flexible, secure, and gas-efficient system for token permissions across multiple blockchains.

## 💡 Key Concepts

### 🔏 EIP-712 Signatures

Permit3 uses EIP-712 typed structured data for secure signature verification, providing users with clear information about what they're signing.

### 🌐 Cross-Chain Operations

Permit3 enables operations across multiple blockchains with a single signature through hash chaining and Unbalanced Merkle Trees.

### 🌲 Unbalanced Merkle Trees

Unbalanced Merkle Trees combine balanced subtrees with an unbalanced upper structure to provide efficient cross-chain proofs while minimizing gas costs.

### 🧩 Witness Functionality

Witness functionality allows including arbitrary data in permits for enhanced verification, enabling complex permission patterns.

### 🔀 Non-Sequential Nonces

Permit3 uses a bitmap-based nonce system for gas-efficient replay protection, enabling concurrent operations.

### 🔄 Flexible Allowance Management

The allowance system supports multiple operation modes, including transfers, increases, decreases, locking, and unlocking.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Home](/docs/README.md) | [Home](/docs/README.md) | [Architecture](/docs/concepts/architecture.md) |