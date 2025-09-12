<a id="documentation-top"></a>
# Permit3 Documentation
## Introduction 
Permit3 enables cross-chain token operations with a single signature. It solves the problem of requiring separate approval signatures for each blockchain when performing multi-chain operations.

### Problem

Multi-chain applications currently require:

- Separate transaction signatures for each chain
- Complex off-chain coordination logic
- Intermediary bridges or relayers
- Multiple wallet interactions for users

### Solution
Permit3 uses Unbalanced Merkle Trees and cryptographic proofs to authorize token operations across multiple blockchains with one signature. Each chain processes only its relevant operations while maintaining cryptographic verification of the complete cross-chain intent.

**Key Capabilities:**

- Single signature for operations across unlimited chains
- Per-chain gas optimization (chains only process their data)
- Cryptographic proof verification without external dependencies
- Backward compatibility with existing Permit2 implementations

### Use Cases

- Cross-chain DEX aggregators
- Multi-chain treasury management
- Portfolio rebalancing across L2s
- Batched multi-chain DeFi operations

This documentation covers the cryptographic architecture, implementation details, and integration patterns for Permit3.

<a id="documentation-sections"></a>
## Documentation Sections

| Section | Description |
|---------|-------------|
| [Core Concepts](#core-concepts) | Foundational understanding of Permit3's architecture and functionality |
| [Guides](#guides) | Step-by-step tutorials for common use cases |
| [API Reference](#api-reference) | Complete API documentation and function references |
| [Examples](#examples) | Code examples demonstrating practical implementations |

###### Quick Navigation: [Revolution](#cross-chain-revolution) | [Sections](#documentation-sections) | [Core Concepts](#core-concepts) | [Guides](#guides) | [API Reference](#api-reference) | [Examples](#examples) | [Features](#feature-highlights) | [Resources](#additional-resources) | [Future](#future-cross-chain)

<a id="core-concepts"></a>
## Core Concepts

Learn about the core concepts that power Permit3's functionality:

- [**Architecture**](./concepts/architecture.md) - Overview of Permit3's contract architecture and component interaction
- [**Multi-Token Support**](./concepts/multi-token-support.md) - Unified permission management for ERC20, ERC721 NFTs, and ERC1155 semi-fungible tokens
- [**Witness Functionality**](./concepts/witness-functionality.md) - Understand how to attach arbitrary data to permits for enhanced verification
- [**Cross-Chain Operations**](./concepts/cross-chain-operations.md) - Learn how Permit3 enables operations across multiple blockchains
- [**Unbalanced Merkle Trees**](./concepts/unbalanced-merkle-tree.md) - Deep dive into the cryptographic structure for efficient cross-chain proofs
- [**Nonce Management**](./concepts/nonce-management.md) - Understanding non-sequential nonces for replay protection
- [**Allowance System**](./concepts/allowance-system.md) - Comprehensive guide to Permit3's flexible allowance mechanisms
- [**Permit2 Compatiblity**](./concepts/permit2-compatibility.md) - How permit3 drops-in with existing permit2 integrations

[View all concepts →](./concepts/README.md)

<a id="guides"></a>
## 📚 Guides

Follow our step-by-step guides to implement Permit3 in your projects:

- [**Quick Start Guide**](./guides/quick-start.md) - Get up and running with Permit3 in minutes
- [**ERC-7702 Integration**](./guides/erc7702-integration.md) - Batch token approvals with Account Abstraction
- [**Witness Integration**](./guides/witness-integration.md) - Implement witness functionality in your application
- [**Cross-Chain Permits**](./guides/cross-chain-permit.md) - Authorize operations across multiple blockchains
- [**Signature Creation**](./guides/signature-creation.md) - Create and validate EIP-712 signatures
- [**Security Best Practices**](./guides/security-best-practices.md) - Secure your Permit3 implementation

[View all guides →](./guides/README.md)

<a id="api-reference"></a>
## 📋 API Reference

Detailed technical documentation for Permit3's interfaces and functions:

- [**API Reference**](./api/api-reference.md) - Complete reference for all Permit3 functions
- [**Data Structures**](./api/data-structures.md) - Detailed documentation of all data structures
- [**Interfaces**](./api/interfaces.md) - Comprehensive interface documentation
- [**Events**](./api/events.md) - All events emitted by Permit3
- [**Error Codes**](./api/error-codes.md) - Error code reference and troubleshooting

[View all API docs →](./api/README.md)

<a id="examples"></a>
## 💻 Examples

Practical examples demonstrating Permit3 implementation:

- [**ERC-7702 Example**](./examples/erc7702-example.md) - Batch token approvals with Account Abstraction
- [**Witness Example**](./examples/witness-example.md) - Implementing witness functionality in a DEX
- [**Cross-Chain Example**](./examples/cross-chain-example.md) - Multi-chain token operations with a single signature
- [**Allowance Management Example**](./examples/allowance-management-example.md) - Comprehensive token approval workflows
- [**Security Example**](./examples/security-example.md) - Implementing security best practices
- [**Integration Example**](./examples/integration-example.md) - Full-stack integration of Permit3

[View all examples →](./examples/README.md)


<a id="additional-resources"></a>
## 🔧 Additional Resources

- [GitHub Repository](https://github.com/permit3/permit3)
- [Contract Deployments](./api/api-reference.md#contract-deployments)
- [Security Audits](./concepts/architecture.md#security-audits)
- [License](../LICENSE)

<a id="future-cross-chain"></a>