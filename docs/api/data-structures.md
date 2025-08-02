<a id="data-structures-top"></a>
# 🔏 Permit3 Data Structures 📋

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > Data Structures

This document provides a detailed reference of all data structures used in Permit3.

###### Navigation: [Core Structures](#core-data-structures) | [UnhingedMerkleTree](#unhingedmerkletree-structures) | [Relations](#relations-between-structures) | [Gas Optimization](#gas-optimization-note)

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
    uint256 chainId;                  // Target blockchain ID
    AllowanceOrTransfer[] permits;    // Array of operations for this chain
}
```

#### Fields

- **chainId**: The blockchain ID where these permits should be executed
- **permits**: Array of AllowanceOrTransfer operations to perform on that chain

### UnhingedPermitProof

Combines a chain's permits with a proof of inclusion in the cross-chain permit root.

```solidity
struct UnhingedPermitProof {
    ChainPermits permits;           // Chain-specific permit data
    bytes32[] unhingedProof;        // Proof of inclusion (Unhinged Merkle Tree proof nodes)
}
```

#### Fields

- **permits**: The permits to execute on the current chain
- **unhingedProof**: Array of Unhinged Merkle Tree proof nodes that prove these permits are part of the signed root. Based on the innovative two-part hybrid structure, but implemented using standard merkle proof format for security and compatibility.

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

Grouping of nonces (salts) to invalidate.

```solidity
struct NoncesToInvalidate {
    bytes32[] salts;    // Array of salt values to invalidate
}
```

#### Fields

- **salts**: Array of salt values to mark as used/invalid

<a id="unhingedmerkletree-structures"></a>
## UnhingedMerkleTree Structures

The UnhingedMerkleTree represents an innovative two-part hybrid structure (balanced merkle tree + sequential hash chain) but uses standard `bytes32[]` arrays for proof implementation. Each element in the array represents a sibling hash needed to verify the proof path from a leaf to the root, efficiently traversing both the balanced and sequential parts of the conceptual structure.

<a id="relations-between-structures"></a>
## Relations Between Structures

```
┌─────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│ bytes32[]       │     │ UnhingedPermitProof│     │ ChainPermits      │
│ (merkle proof)  │◄────┤ unhingedProof     │     │ chainId           │
└─────────────────┘     ├───────────────────┤     ├───────────────────┤
                        │ permits           │◄────┤ permits[]         │◄─┐
                        └───────────────────┘     └───────────────────┘  │
                                                                        │
                        ┌───────────────────┐                          │
                        │ AllowanceOrTransfer│                          │
                        ├───────────────────┤                          │
                        │ modeOrExpiration  │                          │
                        │ token             │                          │
                        │ account           │                          │
                        │ amountDelta       │◄─────────────────────────┘
                        └───────────────────┘
```

This diagram shows how the different data structures relate to each other in the Permit3 system, particularly for cross-chain operations.

<a id="gas-optimization-note"></a>
## Gas Optimization Note

These structures are designed for gas optimization guided by the Unhinged Merkle Tree concept:

- **UnhingedProof**: Simplified to contain only essential proof data while maintaining the benefits of the two-part conceptual structure
- **AllowanceOrTransfer**: Unified structure for multiple operation types to reduce contract size and complexity
- **Two-Part Benefits**: Chain ordering strategies enabled by the conceptual hybrid structure can minimize costs on expensive chains
- **Logarithmic Scaling**: Proof size ensures efficient verification even for large cross-chain operation sets

These optimizations, guided by the innovative two-part design philosophy, are crucial for cost-effective cross-chain operations.