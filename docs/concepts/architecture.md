# Permit3 Architecture

This document provides a comprehensive overview of the Permit3 architecture, explaining how its components work together to enable cross-chain token approvals and transfers.

## Overview

Permit3 is a cross-chain token approval and transfer system that extends the functionality of Permit2 with advanced features:

1. **Cross-Chain Operations**: Execute approvals and transfers across multiple blockchains with a single signature
2. **Non-Sequential Nonces**: Enable concurrent operations and optimize gas usage
3. **Flexible Allowance Management**: Support time-bound permissions with various operation modes
4. **Witness Functionality**: Attach arbitrary data to permits for enhanced verification
5. **EIP-712 Typed Signatures**: Secure signature verification with structured data

## Core Components

The Permit3 system consists of three main components:

### 1. Permit3 Contract

The main contract that inherits from PermitBase and NonceManager, implementing the core functionality:

- Processes permit signatures for approvals and transfers
- Verifies EIP-712 signatures with standard and witness data
- Handles cross-chain operations through hash chaining
- Implements witness functionality for custom data verification

### 2. PermitBase Contract

Manages token approvals and transfers:

- Tracks allowances with amounts and expiration times
- Handles token transfers through approvals
- Implements allowance modes (increase, decrease, lock, unlock)
- Provides emergency account locking functionality

### 3. NonceManager Contract

Handles nonce management for replay protection:

- Uses non-sequential nonces for gas efficiency
- Supports cross-chain nonce invalidation
- Implements salt-based signature replay protection
- Provides domain separation for EIP-712 signatures

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
    uint256 chainId;             // Target chain ID
    AllowanceOrTransfer[] permits; // Operations for this chain
}
```

### Permit3Proof Structure

```solidity
struct Permit3Proof {
    bytes32 preHash;          // Hash of previous chain operations
    ChainPermits permits;     // Permit operations for the current chain
    bytes32[] followingHashes; // Hashes of subsequent chain operations
}
```

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
    uint256 wordPos = uint256(salt) / 256;
    uint256 bitPos = uint256(salt) % 256;
    uint256 bit = 1 << bitPos;
    
    noncesBitmap[owner][wordPos] |= bit;
    
    emit NonceUsed(owner, salt);
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

## Cross-Chain Mechanism

Permit3 enables cross-chain operations through hash chaining:

1. Hash permits for each chain individually
2. Chain these hashes together in a specific order
3. Sign the combined hash
4. Process the portion relevant to the current chain

This approach:
- Requires only one signature for multiple chains
- Ensures operations on each chain are consistent
- Validates chain ID to prevent cross-chain replay attacks
- Supports witness data across chains

### Hash Chaining Example

```solidity
// Chain permit hashes together
bytes32 unbalancedPermitsRoot = proof.preHash;
unbalancedPermitsRoot = keccak256(abi.encodePacked(unbalancedPermitsRoot, _hashChainPermits(proof.permits)));

for (uint256 i = 0; i < proof.followingHashes.length; i++) {
    unbalancedPermitsRoot = keccak256(abi.encodePacked(unbalancedPermitsRoot, proof.followingHashes[i]));
}

// Verify signature against combined hash
bytes32 signedHash = keccak256(abi.encode(
    SIGNED_PERMIT3_TYPEHASH, 
    owner, 
    salt, 
    deadline, 
    timestamp, 
    unbalancedPermitsRoot
));
```

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
   - Single signature for multiple chains
   - Optimized hash chaining

## Integration with External Systems

Permit3 is designed for seamless integration:

1. **Permit2 Compatibility**:
   - Implements IPermit interface
   - Maintains backward compatibility
   - Supports existing integration patterns

2. **ERC20 Token Interaction**:
   - Works with any ERC20 token
   - No special token requirements
   - Compatible with standard token interfaces

3. **Cross-Contract Integration**:
   - Clear interfaces for external contracts
   - Witness functionality for custom verification
   - Support for complex integration patterns

## Conclusion

The Permit3 architecture provides a flexible, secure, and gas-efficient system for cross-chain token approvals and transfers. By extending Permit2 with advanced features like witness functionality and non-sequential nonces, it enables new use cases while maintaining backward compatibility.

The modular design with separate components for allowance management, nonce handling, and core functionality creates a clean architecture that can be extended and maintained efficiently.