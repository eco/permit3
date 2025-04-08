# Permit3 Data Structures

This document provides a detailed reference of all data structures used in Permit3.

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

## UnhingedMerkleTree Structures

### UnhingedProof

Optimized structure for cross-chain proof verification.

```solidity
struct UnhingedProof {
    bytes32[] nodes;       // All proof nodes: [preHash (optional), subtreeProof nodes, followingHashes]
    bytes32 counts;        // Packed metadata
}
```

#### Fields

- **nodes**: Combined array containing all proof components in order
  - preHash (if present): The hash of all preceding chains
  - subtreeProof nodes: For balanced merkle tree verification
  - followingHashes: Hashes of subsequent chains
  
- **counts**: Packed bytes32 value containing:
  - First 120 bits: subtreeProofCount (number of nodes in subtree proof)
  - Next 120 bits: followingHashesCount (number of nodes in following hashes)
  - Next 15 bits: Reserved for future use
  - Last bit: hasPreHash flag (1 if preHash is present, 0 if not)

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

## Gas Optimization Note

Many of these structures are specifically designed for gas optimization:

- **UnhingedProof.counts**: Packs multiple values into a single bytes32 to reduce storage costs
- **hasPreHash flag**: Allows omitting preHash entirely when not needed, saving ~20,000 gas for common cases
- **AllowanceOrTransfer**: Unified structure for multiple operation types to reduce contract size and complexity

These optimizations are crucial for cost-effective cross-chain operations.