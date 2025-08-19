<a id="architecture-top"></a>
# 🔏 Permit3 Architecture 🏛️

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Architecture

This document provides a comprehensive overview of the Permit3 architecture, explaining how its components work together to enable cross-chain token approvals and transfers.

###### Navigation: [Overview](#overview) | [Core Components](#core-components) | [Inheritance Structure](#contract-inheritance-structure) | [Data Structures](#key-data-structures) | [Operations](#core-operations) | [Cross-Chain](#cross-chain-mechanism) | [Security](#security-features) | [Gas Optimization](#gas-optimization) | [Integration](#integration-with-external-systems) | [Audits](#security-audits) | [Conclusion](#conclusion)

<a id="overview"></a>
## 🔍 Overview

Permit3 is a cross-chain token approval and transfer system that extends the functionality of Permit2 with advanced features:

1. 🌉 **Cross-Chain Operations**: Execute approvals and transfers across multiple blockchains with a single signature
2. 🔢 **Non-Sequential Nonces**: Enable concurrent operations and optimize gas usage
3. 🔄 **Flexible Allowance Management**: Support time-bound permissions with various operation modes
4. 🧩 **Witness Functionality**: Attach arbitrary data to permits for enhanced verification
5. 🔏 **EIP-712 Typed Signatures**: Secure signature verification with structured data

<a id="core-components"></a>
## 🧱 Core Components

The Permit3 system consists of three main components:

### 1️⃣  Permit3 Contract

The main contract that inherits from PermitBase and NonceManager, implementing the core functionality:

- 📝 Processes permit signatures for approvals and transfers
- ✅ Verifies EIP-712 signatures with standard and witness data
- 🔗 Handles cross-chain operations through hash chaining
- 🧩 Implements witness functionality for custom data verification

### 2️⃣  PermitBase Contract

Manages token approvals and transfers:

- 📊 Tracks allowances with amounts and expiration times
- 💸 Handles token transfers through approvals
- 🔀 Implements allowance modes (increase, decrease, lock, unlock)
- 🔒 Provides emergency account locking functionality

### 3️⃣  NonceManager Contract

Handles nonce management for replay protection:

- 🧮 Uses non-sequential nonces for gas efficiency
- 🌐 Supports cross-chain nonce invalidation
- 🧂 Implements salt-based signature replay protection
- 🏷️ Provides domain separation for EIP-712 signatures

<a id="contract-inheritance-structure"></a>
## Contract Inheritance Structure

```
                 ┌───────────────┐
                 │   EIP-712     │
                 └───────┬───────┘
                         │
                 ┌───────┴───────┐
                 │ NonceManager  │
                 └───────┬───────┘
                         │
                 ┌───────┴───────┐
                 │  PermitBase   │
                 └───────┬───────┘
                         │
                 ┌───────┴───────┐
                 │    Permit3    │
                 └───────────────┘
```

<a id="key-data-structures"></a>
## Key Data Structures

### Allowance Structure

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when approval expires
    uint48 timestamp;      // Timestamp when approval was set
}
```

### AllowanceOrTransfer Structure

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;  // Operation mode or expiration time
    address token;            // Token address
    address account;          // Spender or recipient
    uint160 amountDelta;      // Amount change
}
```

### ChainPermits Structure

```solidity
struct ChainPermits {
    uint64 chainId;              // Target chain ID (uint64 for gas optimization)
    AllowanceOrTransfer[] permits; // Operations for this chain
}
```

### Cross-Chain Permit Parameters

In the implementation, cross-chain operations use separate parameters:

```solidity
function permit(
    address owner,
    bytes32 salt,
    uint48 deadline,
    uint48 timestamp,
    ChainPermits calldata permits,    // Permit operations for the current chain
    bytes32[] calldata proof,         // Standard merkle proof using OpenZeppelin's MerkleProof
    bytes calldata signature
) external;

// Uses OpenZeppelin's MerkleProof.processProof() with bytes32[] arrays
// Each element represents a sibling hash needed for proof verification
```

<a id="core-operations"></a>
## Core Operations

### 1. Permit Processing

Permit3 supports two main permit functions:

1. **Single Chain Permits**:
   - Process token approvals for a specific chain
   - Verify signature against chain permits
   - Update allowances or execute transfers

2. **Cross-Chain Permits**:
   - Process token approvals across multiple chains
   - Chain permit hashes together for verification
   - Execute operations on current chain only

Both functions can be extended with witness functionality to include custom data in signature verification.

### 2. Allowance Management

Permit3 supports five operation modes controlled by the `modeOrExpiration` parameter:

1. **Transfer Mode** (`modeOrExpiration = 0`):
   - Executes immediate token transfer
   - `account` field represents recipient
   - `amountDelta` represents transfer amount

2. **Decrease Mode** (`modeOrExpiration = 1`):
   - Reduces existing allowance
   - `amountDelta` represents decrease amount
   - Special case: `type(uint160).max` resets to 0

3. **Lock Mode** (`modeOrExpiration = 2`):
   - Locks allowance for security
   - Blocks any increases or transfers
   - Requires newer timestamp to unlock

4. **Unlock Mode** (`modeOrExpiration = 3`):
   - Cancels locked state
   - Sets new allowance amount
   - Requires newer timestamp than lock

5. **Increase Mode** (`modeOrExpiration > 3`):
   - Value represents expiration timestamp
   - Increases allowance by `amountDelta`
   - Updates expiration if timestamp is newer

### 3. Nonce Management

Permit3 uses non-sequential nonces with salt parameters:

```solidity
function _useNonce(address owner, bytes32 salt) internal {
    if (usedNonces[owner][salt] != NONCE_NOT_USED) {
        revert NonceAlreadyUsed(owner, salt);
    }
    usedNonces[owner][salt] = NONCE_USED;
}
```

This approach:
- Enables concurrent operations with different salts
- Optimizes gas usage compared to sequential nonces
- Supports cross-chain nonce management
- Prevents signature replay attacks

### 4. Witness Functionality

Witness functionality extends the standard permit flow:

1. **Type String Construction**:
   ```solidity
   bytes32 typeHash = keccak256(
       abi.encodePacked(PERMIT_WITNESS_TYPEHASH_STUB, witnessTypeString)
   );
   ```

2. **Signature Verification**:
   ```solidity
   bytes32 signedHash = keccak256(
       abi.encode(
           typeHash,
           permitDataHash,
           owner,
           salt,
           deadline,
           timestamp,
           witness
       )
   );
   ```

3. **Processing**:
   After verification, the permit is processed using the standard flow while the application can verify the witness data.

<a id="cross-chain-mechanism"></a>
## Cross-Chain Mechanism

Permit3 enables cross-chain operations through Unbalanced Merkle Trees:

1. Hash permits for each chain individually 
2. Build an Unbalanced Merkle Tree from all chain hashes (two-part structure)
3. Sign the Unbalanced root
4. Generate Unbalanced proofs for each chain  
5. Process the portion relevant to the current chain

This approach leverages the two-part design:
- **Bottom Part**: Efficient membership proofs within individual chains
- **Top Part**: Unbalanced upper structure that minimizes calldata for chains with high gas costs
- **Verification**: Merkle tree verification for security and compatibility
- **Benefits**: One signature for multiple chains with gas optimization potential
- **Security**: Chain ID validation prevents cross-chain replay attacks
- **Extensibility**: Supports witness data across chains with future optimization opportunities

### Unbalanced Merkle tree Example

```solidity
// Calculate the leaf hash for this chain's permits  
bytes32 leaf = permit3.hashChainPermits(proof.permits);

// Verify the Unbalanced Merkle Tree proof using OpenZeppelin's MerkleProof
// (traverses both balanced subtrees and unbalanced upper structure)
bool valid = MerkleProof.processProof(
    proof.proof,
    leaf
) == merkleRoot;

// Verify signature against Unbalanced root
bytes32 signedHash = keccak256(abi.encode(
    SIGNED_PERMIT3_TYPEHASH, 
    owner, 
    salt, 
    deadline, 
    timestamp, 
    merkleRoot  // The hybrid structure root
));
```

<a id="security-features"></a>
## Security Features

Permit3 implements several security features:

1. **Signature Validation**:
   - EIP-712 typed signatures for structured data
   - Signature replay protection through nonces
   - Deadline validation to prevent expired signatures

2. **Access Control**:
   - Allowance-based access for token operations
   - Time-bound permissions with expiration timestamps
   - Owner validation for all operations

3. **Account Locking**:
   - Special locked state for emergency security
   - Operations blocked until explicit unlock
   - Timestamp validation for unlock operations

4. **Chain ID Validation**:
   - Explicit chain ID verification
   - Prevents cross-chain replay attacks
   - Works with witness functionality

5. **Timestamp Ordering**:
   - Operations ordered by timestamp across chains
   - Prevents race conditions in cross-chain operations
   - Critical for asynchronous allowance updates

<a id="gas-optimization"></a>
## Gas Optimization

Permit3 implements several gas optimization strategies:

1. **Non-Sequential Nonces**:
   - Bitmap-based nonce tracking
   - Constant gas cost regardless of nonce value
   - Efficient for concurrent operations

2. **Batched Operations**:
   - Process multiple permits in one transaction
   - Amortize fixed costs across operations
   - Reduce total transaction count

3. **Efficient Storage**:
   - Packed storage slots for allowances
   - Minimal state updates
   - Optimized data types

4. **Cross-Chain Efficiency**:
   - Execute only relevant operations on each chain
   - Single signature for multiple chains leveraging two-part structure
   - Optimized Unbalanced tree structure with gas optimization potential

<a id="integration-with-external-systems"></a>
## Integration with External Systems

Permit3 is designed for seamless integration:

1. **Permit2 Compatibility**:
   - Implements IPermit interface for compatibility with contracts that are already using Permit2 for transfers
   - Existing contracts integrated with Permit2 can work with Permit3 without any changes
   - Maintains backward compatibility while offering enhanced functionality

2. **ERC20 Token Interaction**:
   - Works with any ERC20 token
   - No special token requirements
   - Compatible with standard token interfaces

3. **Cross-Contract Integration**:
   - Clear interfaces for external contracts
   - Witness functionality for custom verification
   - Support for complex integration patterns

<a id="security-audits"></a>
## Security Audits

Permit3 has undergone comprehensive security audits by leading blockchain security firms to ensure that the protocol is robust and secure. The audits focused on key aspects of the protocol including:

1. **Smart Contract Security**: Identifying potential vulnerabilities in the contract code
2. **Cross-Chain Security**: Validating the security of cross-chain operation mechanisms
3. **Cryptographic Verification**: Ensuring the correct implementation of signature schemes and hash functions
4. **Gas Optimization**: Verifying that gas optimizations don't compromise security

To review the complete audit reports, visit the [security documentation](/docs/security/audit-reports.md).

<a id="conclusion"></a>
## Conclusion

The Permit3 architecture provides a flexible, secure, and gas-efficient system for cross-chain token approvals and transfers. By extending Permit2 with advanced features like witness functionality and non-sequential nonces, it enables new use cases while maintaining backward compatibility.

The modular design with separate components for allowance management, nonce handling, and core functionality creates a clean architecture that can be extended and maintained efficiently.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Allowance System](/docs/concepts/allowance-system.md) | [Concepts](/docs/concepts/README.md) | [Cross-Chain Operations](/docs/concepts/cross-chain-operations.md) |