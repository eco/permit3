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
    ChainPermits permits;                       // Chain-specific permit data
    IUnhingedMerkleTree.UnhingedProof unhingedProof;  // Proof of inclusion 
}
```

#### Fields

- **permits**: The permits to execute on the current chain
- **unhingedProof**: Proof that these permits are part of the signed unhinged root

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

### UnhingedProof

Simple structure for merkle proof verification.

```solidity
struct UnhingedProof {
    bytes32[] nodes;       // Array of sibling hashes forming the merkle proof path
}
```

#### Fields

- **nodes**: Array of sibling hashes that form the merkle proof
  - Each hash is a sibling node needed to reconstruct the path to the root
  - Follows standard merkle proof format
  - Uses ordered hashing (smaller value first) for consistency
  - Based on OpenZeppelin's MerkleProof implementation

<a id="relations-between-structures"></a>
## Relations Between Structures

```
┌─────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│ UnhingedProof   │     │ UnhingedPermitProof│     │ ChainPermits      │
├─────────────────┤     ├───────────────────┤     ├───────────────────┤
│ nodes           │◄────┤ unhingedProof     │     │ chainId           │
│ counts          │     ├───────────────────┤     ├───────────────────┤
└─────────────────┘     │ permits           │◄────┤ permits[]         │◄─┐
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

These structures are designed for gas optimization:

- **UnhingedProof**: Simplified to contain only essential merkle proof data
- **AllowanceOrTransfer**: Unified structure for multiple operation types to reduce contract size and complexity
- **Merkle Proofs**: Logarithmic proof size ensures efficient verification even for large operation sets

These optimizations are crucial for cost-effective cross-chain operations.