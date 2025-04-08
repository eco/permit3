# Permit3 API Reference

This section provides comprehensive API documentation for Permit3.

## Available Documentation

- [API Reference](./api-reference.md): Complete reference of all interfaces and functions
- [Data Structures](./data-structures.md): Detailed documentation of Permit3 data structures
- [Events](./events.md): Documentation of all events emitted by Permit3
- [Error Codes](./error-codes.md): List of error codes and their meanings
- [Interfaces](./interfaces.md): Documentation of Permit3 interfaces

## Key Interfaces

### IPermit3

The main interface for Permit3, extending IPermit and INonceManager.

```solidity
interface IPermit3 is IPermit, INonceManager {
    // Functions defined in api-reference.md
}
```

### IPermit

Interface for backwards compatibility with Permit2.

```solidity
interface IPermit {
    // Functions for standard permits and transfers
}
```

### INonceManager

Interface for nonce management and signature validation.

```solidity
interface INonceManager {
    // Functions for nonce management
}
```

## Function Categories

### Standard Permit Functions

Functions for processing standard permits (single-chain and cross-chain).

### Witness Permit Functions

Functions for processing permits with witness data for enhanced verification.

### Token Transfer Functions

Functions for transferring tokens using permits or allowances.

### Allowance Management Functions

Functions for managing token allowances with flexible modes.

### Nonce Management Functions

Functions for handling nonces to prevent replay attacks.

## Using the API

For practical examples of using the Permit3 API, see the [Examples](../examples/index.md) section.