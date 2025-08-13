<a id="data-structures-top"></a>
# 🔏 Permit3 Data Structures 📋

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > Data Structures

This document provides a detailed reference of all data structures used in Permit3.

###### Navigation: [Core Structures](#core-data-structures) | [Merkle Tree Methodology](#merkle-tree-methodology) | [Relations](#relations-between-structures) | [Gas Optimization](#gas-optimization-note)

<a id="core-data-structures"></a>
## Core Data Structures

### AllowanceOrTransfer

The central structure for all permission operations in Permit3. This unified structure handles transfers, allowance increases/decreases, and account locking/unlocking.

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;    // Operation mode or expiration timestamp
    address token;              // Token address
    address account;            // Spender address or transfer recipient
    uint160 amountDelta;        // Amount change or transfer amount
}
```

#### Fields

- **modeOrExpiration**: Determines the operation type
  - `0`: Transfer mode (execute immediate transfer)
  - `1`: Decrease mode (reduce allowance)
  - `2`: Lock mode (lock allowances)
  - `3`: Unlock mode (unlock allowances)
  - `>3`: Increase mode (value serves as expiration timestamp)

- **token**: The ERC20 token address this operation applies to

- **account**: 
  - For transfers: The recipient address
  - For allowances: The approved spender address
  - For lock/unlock: Often set to `address(0)`

- **amountDelta**:
  - For transfers: The transfer amount
  - For increases: The amount to increase the allowance by
  - For decreases: The amount to decrease the allowance by
  - Special case: `type(uint160).max` means unlimited approval for increases or resetting to 0 for decreases

### ChainPermits

Groups multiple AllowanceOrTransfer operations for a specific blockchain.

```solidity
struct ChainPermits {
    uint64 chainId;                   // Target blockchain ID (uint64 for gas optimization)
    AllowanceOrTransfer[] permits;    // Array of operations for this chain
}
```

#### Fields

- **chainId**: The blockchain ID where these permits should be executed (uint64 type for gas efficiency)
- **permits**: Array of AllowanceOrTransfer operations to perform on that chain

### Cross-Chain Permit Parameters

In the implementation, cross-chain operations use separate parameters instead of a struct:

- **ChainPermits calldata permits**: The permits to execute on the current chain
- **bytes32[] calldata proof**: Standard merkle proof array that proves these permits are part of the signed root using OpenZeppelin's MerkleProof.processProof()

### Allowance

Internal structure used to track token allowances.

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when the allowance expires
    uint48 timestamp;      // Timestamp when allowance was last updated
}
```

#### Fields

- **amount**: The quantity of tokens approved for spending
- **expiration**: Unix timestamp when the allowance becomes invalid
- **timestamp**: Last update timestamp, used for ordering operations across chains

### NoncesToInvalidate

Grouping of nonces (salts) to invalidate for a specific chain.

```solidity
struct NoncesToInvalidate {
    uint64 chainId;     // Target chain identifier
    bytes32[] salts;    // Array of salt values to invalidate
}
```

#### Fields

- **chainId**: The blockchain ID where these nonces should be invalidated
- **salts**: Array of salt values to mark as used/invalid

### Cross-Chain Nonce Invalidation Parameters

For cross-chain nonce invalidation operations, separate parameters are used:

- **NoncesToInvalidate calldata invalidations**: The nonce invalidation data for the current chain
- **bytes32[] calldata proof**: Standard merkle proof array for cross-chain verification

### TokenSpenderPair

Simple pairing of token and spender addresses for batch operations.

```solidity
struct TokenSpenderPair {
    address token;      // Token contract address
    address spender;    // Spender address
}
```

#### Fields

- **token**: The address of the ERC20 token contract
- **spender**: The address approved to spend the token

### AllowanceTransferDetails

Details required for token transfer operations.

```solidity
struct AllowanceTransferDetails {
    address from;       // Owner of the tokens
    address to;         // Recipient of the tokens
    uint160 amount;     // Number of tokens to transfer
    address token;      // Token contract address
}
```

#### Fields

- **from**: The address that owns the tokens being transferred
- **to**: The address that will receive the tokens
- **amount**: The quantity of tokens to transfer
- **token**: The address of the ERC20 token contract

<a id="merkle-tree-methodology"></a>
## Merkle Tree Methodology

The Unbalanced Merkle tree methodology uses standard `bytes32[]` arrays for proof implementation, compatible with OpenZeppelin's MerkleProof.processProof(). Each element in the array represents a sibling hash needed to verify the proof path from a leaf to the root.

<a id="relations-between-structures"></a>
## Relations Between Structures

```
┌───────────────────┐     ┌───────────────────┐
│ ChainPermits      │     │ bytes32[]         │
│ chainId           │     │ (merkle proof)    │
├───────────────────┤     └───────────────────┘
│ permits[]         │◄─┐  Passed as separate parameters
└───────────────────┘  │  to permit() function
                       │
┌───────────────────┐  │
│ AllowanceOrTransfer│  │
├───────────────────┤  │
│ modeOrExpiration  │  │
│ token             │  │
│ account           │  │
│ amountDelta       │◄─┘
└───────────────────┘
```

This diagram shows how the different data structures relate to each other in the Permit3 system, particularly for cross-chain operations.

<a id="gas-optimization-note"></a>
## Gas Optimization Note

These structures are designed for gas optimization:

- **Merkle Proofs**: Standard bytes32[] arrays for maximum compatibility with existing libraries
- **AllowanceOrTransfer**: Unified structure for multiple operation types to reduce contract size and complexity