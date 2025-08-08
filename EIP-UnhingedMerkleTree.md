---
eip: 9999
title: Unhinged Merkle Trees for Cross-Chain Operations
description: A methodology for structuring merkle trees to enable efficient cross-chain proofs using standard merkle tree verification
author: 🔏 Permit3 Team (@permit3)
discussions-to: https://ethereum-magicians.org/t/eip-9999-unhinged-merkle-trees
status: Draft
type: Standards Track
category: ERC
created: 2025-04-04
requires: 712
---

## Abstract

This EIP defines the "Unhinged Merkle Tree" methodology - a way of structuring merkle trees for cross-chain operations that enables a single signature to authorize operations across multiple blockchain networks. The methodology uses standard merkle tree verification (such as OpenZeppelin's MerkleProof.processProof()) but applies it to a specific tree construction pattern optimized for cross-chain scenarios.

## Motivation

Cross-chain operations require a way to prove that a specific operation is part of a larger set of authorized cross-chain operations. Traditional approaches either require separate signatures for each chain or complex verification schemes.

The Unhinged Merkle Tree methodology addresses these challenges by:
1. Enabling a single signature to authorize operations across multiple chains
2. Using standard, battle-tested merkle tree verification
3. Optimizing gas costs through strategic tree construction
4. Providing a simple, implementable approach using existing libraries

## Specification

### Core Concept

An Unhinged Merkle Tree is a methodology for combining operations across multiple blockchain networks into a single merkle tree that can be verified using standard merkle proof verification algorithms.

The key insight is to structure the tree so that:
1. **Cross-chain operations** are organized in a way that minimizes proof size for each individual chain
2. **Standard verification** can be used without custom libraries or complex proof formats
3. **Gas optimization** is achieved through strategic ordering of chains

### Tree Construction Methodology

#### Step 1: Organize Operations by Chain
For each blockchain network, collect all operations that will be executed on that chain. Hash each operation to create leaf nodes.

#### Step 2: Build the Combined Tree
Instead of creating separate trees for each chain, build a single merkle tree that contains all operations from all chains. The tree structure follows standard merkle tree construction rules:

```
                    ROOT
                   /    \
                  H1     H2
                 / \    / \
               H3   H4 H5  H6
              /|   |\ |\ |\
            Op1 Op2... Operations from all chains
```

Where operations from different chains are mixed throughout the tree structure.

#### Step 3: Strategic Ordering for Gas Optimization
Operations should be ordered within the tree based on gas cost considerations:
- Operations for chains with expensive calldata (like Ethereum mainnet) should be positioned to require shorter proofs
- Operations for chains with cheaper calldata (like L2s) can have longer proofs without significantly impacting total costs

### Why "Unhinged"?

The methodology is called "unhinged" because it deliberately breaks away from the traditional approach of creating separate, isolated merkle trees for each chain. Instead, it creates a single "unhinged" tree that spans multiple chains, allowing operations from different networks to be proven as part of the same authorization set.

### Proof Format and Verification

Unhinged Merkle Trees use **standard merkle proof verification** without any custom formats or complex structures. The proof is simply:

```solidity
bytes32[] proof;  // Standard merkle proof array
```

#### Verification Process

Verification uses standard merkle tree algorithms, such as OpenZeppelin's `MerkleProof.processProof()`:

```solidity
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

function verifyOperation(
    bytes32[] calldata proof,
    bytes32 root,
    bytes32 operationHash
) internal pure returns (bool) {
    return MerkleProof.processProof(proof, operationHash) == root;
}
```

This approach provides several key advantages:
1. **Proven Security**: Uses battle-tested merkle tree verification
2. **Library Compatibility**: Works with existing merkle proof libraries (OpenZeppelin, etc.)
3. **Simplicity**: No custom proof formats or complex verification logic
4. **Gas Efficiency**: Standard O(log n) verification complexity

### Tree Generation Process

Building an Unhinged Merkle Tree follows standard merkle tree construction:

1. **Collect all operations** from all chains that need to be authorized by a single signature
2. **Hash each operation** to create leaf nodes using a consistent hashing scheme
3. **Order operations strategically** to optimize gas costs (see Gas Optimization section below)
4. **Build the tree** using standard merkle tree construction algorithms
5. **Sign the root** using EIP-712 or other signature schemes

The resulting tree can be verified using any standard merkle proof library.

### Gas Optimization Through Operation Ordering

The power of the Unhinged Merkle Tree methodology lies in strategic operation ordering within the tree:

#### Optimization Strategy
- **Expensive chains first**: Place operations for high-gas-cost chains (like Ethereum mainnet) in positions that result in shorter merkle proofs
- **Cheaper chains later**: Place operations for low-gas-cost chains (like L2s) in positions where longer proofs are acceptable

#### Implementation Approach
When building the tree, position operations so that:
- Ethereum mainnet operations require fewer proof elements
- Layer 2 and sidechain operations can have longer proofs without significantly impacting total transaction costs

This ordering strategy can result in significant gas savings for cross-chain operations, as the most expensive verification costs are minimized.

## Rationale

The Unhinged Merkle Tree methodology is chosen for several key reasons:

1. **Simplicity**: Uses standard merkle tree verification without custom algorithms or complex proof structures
2. **Compatibility**: Works with existing merkle proof libraries like OpenZeppelin's MerkleProof
3. **Gas Efficiency**: Enables optimization through strategic operation ordering while maintaining O(log n) complexity
4. **Security**: Leverages battle-tested merkle tree verification patterns
5. **Flexibility**: Can accommodate arbitrary numbers of chains and operations without architectural changes

The methodology provides a clean way to authorize cross-chain operations with a single signature while using only standard, well-understood cryptographic primitives.

## Backwards Compatibility

This EIP is fully compatible with existing Ethereum standards and does not require any changes to the Ethereum protocol. It can be implemented in smart contracts using existing Solidity functions.

## Security Considerations

### Proof Ordering

The security of Unhinged Merkle Trees depends on the consistent ordering of operations and chains. Implementations must ensure that:

1. Operations within each chain's balanced subtree are ordered consistently
2. Chains are processed in the specified canonical order
3. The verification algorithm correctly processes the subtree proof nodes

### Replay Protection

Cross-chain proofs should include appropriate replay protection mechanisms such as:

1. Chain-specific identifiers to prevent proofs from being reused across different chains
2. Nonces or timestamps to prevent proofs from being reused within the same chain
3. Expiration times to limit the validity period of proofs

### Root Signing

The Unhinged Root should be signed using secure methods such as EIP-712, which provides structured data signing with domain separation.

## Reference Implementation

The following shows how Unhinged Merkle Trees can be implemented using standard merkle tree libraries:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title UnhingedMerkleTreeExample
 * @notice Example implementation showing how to use standard merkle tree verification
 * for cross-chain operations using the Unhinged Merkle Tree methodology
 */
contract UnhingedMerkleTreeExample {
    
    /**
     * @notice Verify that an operation is part of an authorized cross-chain set
     * @param proof Standard merkle proof array
     * @param root The signed merkle root authorizing all cross-chain operations
     * @param operationHash Hash of the operation being verified
     * @return True if the operation is authorized, false otherwise
     */
    function verifyOperation(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 operationHash
    ) external pure returns (bool) {
        return MerkleProof.processProof(proof, operationHash) == root;
    }
    
    /**
     * @notice Example of how operations might be hashed consistently
     * @param chainId The chain where the operation will be executed
     * @param to The target address for the operation
     * @param value The value being transferred
     * @param data The calldata for the operation
     * @param nonce A unique nonce to prevent replay attacks
     * @return The hash of the operation
     */
    function hashOperation(
        uint256 chainId,
        address to,
        uint256 value,
        bytes calldata data,
        uint256 nonce
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(chainId, to, value, data, nonce));
    }
    
    /**
     * @notice Execute a cross-chain authorized operation
     * @param proof Merkle proof showing this operation is authorized
     * @param root The signed root authorizing this operation set
     * @param chainId The chain this operation targets
     * @param to The target address
     * @param value The value to transfer
     * @param data The calldata to execute
     * @param nonce The operation nonce
     */
    function executeAuthorizedOperation(
        bytes32[] calldata proof,
        bytes32 root,
        uint256 chainId,
        address to,
        uint256 value,
        bytes calldata data,
        uint256 nonce
    ) external {
        // Verify this operation is authorized by the signed root
        bytes32 operationHash = hashOperation(chainId, to, value, data, nonce);
        require(
            MerkleProof.processProof(proof, operationHash) == root,
            "Operation not authorized"
        );
        
        // Execute the operation
        (bool success,) = to.call{value: value}(data);
        require(success, "Operation execution failed");
    }
}
```

### Key Implementation Notes

1. **Standard Library Usage**: The implementation uses OpenZeppelin's `MerkleProof.processProof()` without modification
2. **Simple Proof Format**: Proofs are just `bytes32[]` arrays as expected by standard merkle libraries
3. **Consistent Hashing**: Operations are hashed consistently across all chains using the same scheme
4. **Gas Optimization**: The tree construction process (not shown) would order operations to minimize proof sizes for expensive chains

## Applications

Unhinged Merkle Trees have applications in various cross-chain scenarios:

1. **Cross-Chain Permit Systems**: Allowing a single signature to authorize token operations across multiple chains
2. **Governance Systems**: Enabling single-signature voting across multiple chains
3. **Bridging Protocols**: Providing efficient verification of cross-chain transfers
4. **Distributed Identity**: Attesting to account ownership across chains
5. **Cross-Chain NFTs**: Proving ownership across multiple chains
6. **Layer 2 Rollups**: Creating compact proofs for multi-rollup systems

## Copyright

Copyright and related rights waived via CC0.