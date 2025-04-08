# Permit3 Documentation

Welcome to the comprehensive documentation for Permit3, a cross-chain token approval and transfer system extending Permit2 with advanced capabilities through UnhingedMerkleTree proofs and non-sequential nonces.

## 📑 Documentation Sections

| Section | Description |
|---------|-------------|
| [Core Concepts](#core-concepts) | Foundational understanding of Permit3's architecture and functionality |
| [Guides](#guides) | Step-by-step tutorials for common use cases |
| [API Reference](#api-reference) | Complete API documentation and function references |
| [Examples](#examples) | Code examples demonstrating practical implementations |

## 🏗️ Core Concepts

Learn about the core concepts that power Permit3's functionality:

- [**Architecture**](./concepts/architecture.md) - Overview of Permit3's contract architecture and component interaction
- [**Witness Functionality**](./concepts/witness-functionality.md) - Understand how to attach arbitrary data to permits for enhanced verification
- [**Cross-Chain Operations**](./concepts/cross-chain-operations.md) - Learn how Permit3 enables operations across multiple blockchains
- [**Unhinged Merkle Trees**](./concepts/unhinged-merkle-tree.md) - Deep dive into the cryptographic structure for efficient cross-chain proofs
- [**Nonce Management**](./concepts/nonce-management.md) - Understanding non-sequential nonces for replay protection
- [**Allowance System**](./concepts/allowance-system.md) - Comprehensive guide to Permit3's flexible allowance mechanisms

[View all concepts →](./concepts/README.md)

## 📚 Guides

Follow our step-by-step guides to implement Permit3 in your projects:

- [**Quick Start Guide**](./guides/quick-start.md) - Get up and running with Permit3 in minutes
- [**Witness Integration**](./guides/witness-integration.md) - Implement witness functionality in your application
- [**Cross-Chain Permits**](./guides/cross-chain-permit.md) - Authorize operations across multiple blockchains
- [**Signature Creation**](./guides/signature-creation.md) - Create and validate EIP-712 signatures
- [**Security Best Practices**](./guides/security-best-practices.md) - Secure your Permit3 implementation

[View all guides →](./guides/README.md)

## 📋 API Reference

Detailed technical documentation for Permit3's interfaces and functions:

- [**API Reference**](./api/api-reference.md) - Complete reference for all Permit3 functions
- [**Data Structures**](./api/data-structures.md) - Detailed documentation of all data structures
- [**Interfaces**](./api/interfaces.md) - Comprehensive interface documentation
- [**Events**](./api/events.md) - All events emitted by Permit3
- [**Error Codes**](./api/error-codes.md) - Error code reference and troubleshooting

[View all API docs →](./api/README.md)

## 💻 Examples

Practical examples demonstrating Permit3 implementation:

- [**Witness Example**](./examples/witness-example.md) - Implementing witness functionality in a DEX
- [**Cross-Chain Example**](./examples/cross-chain-example.md) - Multi-chain token operations with a single signature
- [**Allowance Management Example**](./examples/allowance-management-example.md) - Comprehensive token approval workflows
- [**Security Example**](./examples/security-example.md) - Implementing security best practices
- [**Integration Example**](./examples/integration-example.md) - Full-stack integration of Permit3

[View all examples →](./examples/README.md)

## 🚀 Getting Started

If you're new to Permit3, we recommend starting with the [Quick Start Guide](./guides/quick-start.md) to get a basic implementation up and running quickly. Then explore the [Core Concepts](./concepts/README.md) to gain a deeper understanding of how Permit3 works.

## 🔍 Feature Highlights

| Feature | Description |
|---------|-------------|
| **Cross-Chain Operations** | Authorize token operations across multiple blockchains with a single signature |
| **Witness Functionality** | Attach arbitrary data to permits for enhanced verification and complex permission patterns |
| **Flexible Allowance System** | Comprehensive tools for managing token permissions with different modes and expirations |
| **Gas Optimization** | Efficient designs for minimizing gas costs across all operations |
| **Security Controls** | Robust security features including account locking and permission revocation |
| **Permit2 Compatibility** | Backwards compatibility with existing Permit2 integrations |

## 🔧 Additional Resources

- [GitHub Repository](https://github.com/permit3/permit3)
- [Contract Deployments](./api/api-reference.md#contract-deployments)
- [Security Audits](./concepts/architecture.md#security-audits)
- [License](../LICENSE)

---

*This documentation is comprehensive but continuously evolving. If you have suggestions for improvements, please open an issue or pull request in the GitHub repository.*