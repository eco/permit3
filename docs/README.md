# Permit3 Documentation

Welcome to the comprehensive documentation for Permit3, a cross-chain token approval and transfer system extending Permit2 with advanced capabilities through hash chaining and non-sequential nonces.

## Overview

Permit3 enables seamless cross-chain token approvals and transfers while maintaining backward compatibility with existing Permit2 contracts. By implementing advanced features like witness functionality, cross-chain operations, and enhanced security controls, Permit3 provides a flexible and secure foundation for token permission management across multiple blockchains.

## Key Features

- **Cross-Chain Compatibility**: Single signature can authorize operations across multiple chains
- **Unhinged Merkle Trees**: Optimized data structure for efficient cross-chain proofs
- **Witness Functionality**: Attach arbitrary data to permit operations for enhanced verification
- **Flexible Nonce System**: Non-sequential nonces for concurrent operations and gas optimization
- **Time-bound Permissions**: Approvals can be set to expire automatically
- **Account Locking**: Emergency security mechanism to lock token access
- **Batched Operations**: Process multiple token approvals and transfers in one transaction
- **EIP-712 Typed Signatures**: Enhanced security through structured data signing
- **Permit2 Compatibility**: Maintains backward compatibility with existing integrations

## Documentation Sections

- [Concepts](./concepts/): Core concepts and architecture of Permit3
- [Guides](./guides/): Step-by-step guides for common use cases
- [API Reference](./api/): Detailed API documentation and function signatures
- [Examples](./examples/): Code examples and implementation patterns

## Getting Started

For quick integration, check out the [Quick Start Guide](./guides/quick-start.md).

For a detailed understanding of Permit3's architecture and capabilities, start with the [Core Concepts](./concepts/architecture.md).

## Permit3: The Cross-Chain Signing Future

Permit3 unlocks a one-click/signature cross-chain future by enabling users to authorize token operations across multiple blockchains with a single signature. This revolutionary approach eliminates the need for separate transactions on each chain, significantly improving user experience and reducing gas costs while maintaining robust security.

By implementing witness functionality, Permit3 also enables advanced use cases where smart contracts can verify arbitrary data as part of the permission process, opening up new possibilities for secure cross-chain applications.

## License

Permit3 is released under the [MIT License](../LICENSE).