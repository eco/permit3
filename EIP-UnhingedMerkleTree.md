---
eip: 9999
title: Unhinged Merkle Trees for Cross-Chain Proofs
description: A standardized method for creating and verifying proofs across multiple blockchain networks using a hybrid tree structure
author: Permit3 Team (@permit3)
discussions-to: https://ethereum-magicians.org/t/eip-9999-unhinged-merkle-trees
status: Draft
type: Standards Track
category: ERC
created: 2025-04-04
requires: 712
---

## Abstract

This EIP proposes a standardized method for creating and verifying proofs across multiple blockchain networks using a hybrid tree structure with a clear two-part design: a balanced Merkle tree for efficient membership proofs combined with sequential hash chaining for linking across chains. This structure, named "Unhinged Merkle Tree," enables efficient and compact proofs for cross-chain operations while maintaining security guarantees.

## Motivation

Cross-chain operations have become increasingly important as blockchain ecosystems expand to multiple networks. However, current implementations lack a standardized, gas-efficient method for proving inclusion in multi-chain transaction sets. 

Common challenges in cross-chain operations include:
1. Gas inefficiency when verifying operations across multiple chains
2. Complexity in managing proofs for different chains
3. Difficulty in maintaining a single authorization signature for multiple chains
4. Lack of standardization in cross-chain proof formats

The Unhinged Merkle Tree structure addresses these challenges by:
1. Minimizing per-chain proof size through its hybrid two-part approach
2. Allowing a single signature to authorize operations across an arbitrary number of chains
3. Providing a standardized format for cross-chain proofs
4. Maintaining security guarantees while optimizing for gas efficiency

## Specification

### Definitions

- **Balanced Subtree**: A traditional Merkle tree for data within a single chain
- **Unhinged Chain**: A sequential hash chain connecting the roots of balanced subtrees
- **Leaf Node**: Individual data element in a balanced subtree
- **Subtree Root**: The root hash of a balanced Merkle tree for a single chain
- **Unhinged Root**: The final hash resulting from the sequential chaining of subtree roots

### Two-Part Structure

The key insight of the Unhinged Merkle Tree is its distinct two-part structure:

```
               [H1] → [H2] → [H3] → ROOT
            /      \      \      \
          [BR]    [D5]   [D6]   [D7]  
         /     \
     [BH1]     [BH2]
    /    \     /    \
[D1]    [D2] [D3]  [D4]
```

Where:
- **Bottom Part**: A standard balanced Merkle tree for efficient membership proofs
  - [BR] is the balanced root
  - [BH1], [BH2] are balanced hash nodes
  - [D1]-[D4] are the leaf data points
  
- **Top Part**: A sequential hash chain for efficiently linking across chains
  - Starts with the balanced root [BR]
  - Incorporates additional data points [D5], [D6], [D7]
  - Creates the hash chain [H1] → [H2] → [H3] → ROOT

This hybrid approach combines the benefits of both structures:
- Efficient membership proofs from the balanced part (O(log n) complexity) 
- Minimal gas usage from the sequential chain part
- Flexibility to include both tree-structured data and sequential data in a single signed root

The Unhinged Merkle Tree consists of:

1. **Balanced Subtrees**: Each chain has its own balanced Merkle tree of operations. These follow standard Merkle tree construction rules where leaf nodes are paired and hashed recursively until a single root hash is obtained.

2. **Unhinged Chain**: The roots of these balanced subtrees are chained sequentially to form the "unhinged chain" through iterative hashing:
   ```
   result = subtreeRoot1
   result = hashLink(result, subtreeRoot2)
   result = hashLink(result, subtreeRoot3)
   ...
   result = hashLink(result, subtreeRootN)
   ```

The final `result` is the Unhinged Root that can be signed using EIP-712 or other signature schemes.

### Proof Format

The proof format for an Unhinged Merkle Tree is defined as a highly optimized structure:

```solidity
struct UnhingedProof {
    bytes32[] nodes;             // All nodes: [preHash (if present), subtreeProof nodes..., followingHashes...]
    bytes32 counts;              // Packed data including counts and flags
}
```

Where:
- `nodes`: A single array containing all relevant nodes in order: preHash (if present), subtree proof nodes, and following hashes
- `counts`: A packed bytes32 value that efficiently stores:
  - First 120 bits: subtreeProofCount (number of nodes in subtree proof)
  - Next 120 bits: followingHashesCount (number of nodes in following hashes)
  - Next 15 bits: Reserved for future use
  - Last bit: hasPreHash flag (1 if preHash is present, 0 if not)

This optimized format has several advantages:
1. It avoids separate array allocations for subtree proofs and following hashes
2. It allows omitting the preHash entirely when not needed, saving significant gas costs
3. It packs all metadata into a single bytes32 value, reducing storage and calldata costs
4. It reserves bits for future extensions without breaking the interface

#### Gas Optimization with hasPreHash Flag

The hasPreHash flag (last bit in the counts value) enables significant gas optimization by allowing proofs to completely omit the preHash value from the nodes array when it's not needed. This provides multiple benefits:

1. **Reduced Calldata Size**: By omitting the 32-byte preHash value, transaction calldata is smaller, directly reducing gas costs
2. **Simplified Verification**: When hasPreHash=false, verification starts directly with the subtree root
3. **Optimized for Common Cases**: Particularly effective for first chains in sequences or single-chain operations

Gas measurements demonstrate significant savings for typical transactions using this optimization.

### Verification Algorithm

To verify an element is included in an Unhinged Merkle Tree:

1. **Extract metadata from packed counts**:
   - Extract subtreeProofCount (120 bits): `uint120 subtreeProofCount = uint120(value >> 136)`
   - Extract followingHashesCount (120 bits): `uint120 followingHashesCount = uint120((value >> 16) & ((1 << 120) - 1))`
   - Extract hasPreHash flag (1 bit): `bool hasPreHash = (value & 1) == 1`

2. **Extract nodes from the array**:
   - Validate that nodes array has sufficient elements
   - If hasPreHash is true, get preHash from nodes[0] and offset subsequent indices
   - Extract subtree proof nodes from the appropriate positions
   - Extract following hashes from the end of the array

3. **Verify the balanced subtree proof**:
   - Use standard Merkle proof verification to check that the element is included in the current chain's subtree
   - Calculate the subtree root

4. **Recalculate the unhinged chain**:
   - If hasPreHash is true:
     - Start with preHash from nodes[0]
     - Append the calculated subtree root: `result = keccak256(abi.encodePacked(preHash, subtreeRoot))`
   - If hasPreHash is false:
     - Start directly with the subtree root: `result = subtreeRoot`
   - Sequentially append each following hash: `result = keccak256(abi.encodePacked(result, followingHash))`

5. **Verification**:
   - Compare the final calculated hash against the signed Unhinged Root
   - If they match, the proof is valid

### Generating an Unhinged Merkle Tree

To generate an Unhinged Merkle Tree:

1. For each chain:
   - Collect all operations for that chain
   - Construct a balanced Merkle tree of these operations
   - Store the root hash of this tree

2. Create the unhinged chain:
   - Start with an empty hash or convention (e.g., `bytes32(0)`)
   - Iteratively hash with each subtree root in order
   - The final hash is the Unhinged Root to be signed

3. Generate proofs for each chain:
   - For each chain, create the appropriate `UnhingedProof` structure
   - Calculate the `preHash` based on all previous chains
   - Include the balanced subtree proof for the relevant elements
   - Include the roots of all subsequent chains in `followingHashes`

### Chain Ordering

For consistent results across implementations, chains must be processed in a canonical ordering. This EIP recommends ordering by chain ID in ascending order, but implementations may choose other ordering schemes (such as gas efficiency) as long as the ordering is consistent and specified.

## Rationale

The hybrid approach of balanced Merkle trees combined with sequential hash chaining is chosen for several reasons:

1. **Gas Efficiency**: Traditional Merkle trees would require including proofs for all cross-chain operations, which becomes inefficient as the number of chains increases. The unhinged approach allows each chain to only process what's relevant to it.

2. **Simplicity**: The verification algorithm is straightforward and easy to implement in smart contracts, requiring only basic hash operations.

3. **Flexibility**: The structure can accommodate an arbitrary number of chains and operations per chain without significant complexity increases.

4. **Compatibility**: The approach is compatible with existing EIP-712 signatures and can be integrated into current cross-chain protocols.

The name "Unhinged" Merkle Tree reflects that the top-level structure deliberately deviates from the traditional balanced approach, creating an "unhinged" but more efficient structure for cross-chain applications.

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

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UnhingedMerkleTree {
    /**
     * @notice Optimized proof structure for Unhinged Merkle Tree
     * @param nodes Array of all proof nodes in sequence: [preHash (if present), subtreeProof nodes..., followingHashes...]
     * @param counts Packed bytes32 that contains all auxiliary data:
     *        - First 120 bits: Number of nodes in subtreeProof
     *        - Next 120 bits: Number of nodes in followingHashes
     *        - Next 15 bits: Reserved for future use
     *        - Last bit: Flag indicating if preHash is present (1) or not (0)
     */
    struct UnhingedProof {
        bytes32[] nodes;
        bytes32 counts;
    }
    
    /**
     * @dev Verifies an Unhinged Merkle proof
     * @param leaf The leaf node being proven
     * @param proof The optimized proof structure containing all necessary components
     * @param unhingedRoot The signed root of the complete unhinged tree
     * @return True if the proof is valid, false otherwise
     */
    function verify(
        bytes32 leaf,
        UnhingedProof calldata proof,
        bytes32 unhingedRoot
    ) internal pure returns (bool) {
        // Extract counts from packed data
        (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) = extractCounts(proof.counts);
        
        // Calculate minimum required nodes
        uint256 minRequiredNodes = subtreeProofCount + followingHashesCount;
        if (hasPreHash) {
            minRequiredNodes += 1;
        }
        
        // Verify array size is sufficient
        if (proof.nodes.length < minRequiredNodes) {
            return false;
        }
        
        // Extract proof components and establish starting points
        bytes32 calculatedRoot;
        uint256 subtreeProofStartIndex;
        
        if (hasPreHash) {
            // If we have a preHash, use it as the starting point
            calculatedRoot = proof.nodes[0];
            subtreeProofStartIndex = 1;
        } else {
            // If no preHash, start with the subtree root directly
            subtreeProofStartIndex = 0;
        }
        
        // Create subtree proof array in memory
        bytes32[] memory subtreeProof = new bytes32[](subtreeProofCount);
        for (uint256 i = 0; i < subtreeProofCount; i++) {
            subtreeProof[i] = proof.nodes[subtreeProofStartIndex + i];
        }
        
        // First verify the balanced subtree proof
        bytes32 subtreeRoot = verifyBalancedSubtree(leaf, subtreeProof);
        
        // Then recalculate the unhinged chain
        if (hasPreHash) {
            // If we have a preHash, hash it with the subtree root
            calculatedRoot = keccak256(abi.encodePacked(calculatedRoot, subtreeRoot));
        } else {
            // If no preHash, the subtree root is our starting point
            calculatedRoot = subtreeRoot;
        }
        
        // Add all following chain hashes
        uint256 followingHashesStartIndex = subtreeProofStartIndex + subtreeProofCount;
        for (uint256 i = 0; i < followingHashesCount; i++) {
            calculatedRoot = keccak256(abi.encodePacked(
                calculatedRoot, 
                proof.nodes[followingHashesStartIndex + i]
            ));
        }
        
        // Verify the calculated root matches the signed root
        return calculatedRoot == unhingedRoot;
    }
    
    /**
     * @dev Extract counts from packed bytes32
     * @param counts The packed counts value
     * @return subtreeProofCount Number of nodes in the subtree proof
     * @return followingHashesCount Number of nodes in the following hashes
     * @return hasPreHash Flag indicating if preHash is present
     */
    function extractCounts(bytes32 counts) internal pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) {
        uint256 value = uint256(counts);
        
        // Extract the different parts from the packed value
        subtreeProofCount = uint120(value >> 136);  // First 120 bits
        followingHashesCount = uint120((value >> 16) & ((1 << 120) - 1));  // Next 120 bits
        // Skip 15 bits reserved for future use
        hasPreHash = (value & 1) == 1;  // Last bit
    }
    
    /**
     * @dev Pack counts into a single bytes32
     * @param subtreeProofCount Number of nodes in the subtree proof
     * @param followingHashesCount Number of nodes in the following hashes
     * @param hasPreHash Flag indicating if preHash is present
     * @return counts The packed counts value
     */
    function packCounts(uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) internal pure returns (bytes32) {
        // Make sure the values fit within the bit ranges
        require(subtreeProofCount < (1 << 120), "SubtreeProofCount overflow");
        require(followingHashesCount < (1 << 120), "FollowingHashesCount overflow");
        
        // Pack the values
        uint256 packedValue = 0;
        packedValue |= uint256(subtreeProofCount) << 136;  // First 120 bits
        packedValue |= uint256(followingHashesCount) << 16;  // Next 120 bits
        // Bits 1-15 are reserved for future use (zeros)
        if (hasPreHash) {
            packedValue |= 1;  // Set the last bit if preHash is present
        }
        
        return bytes32(packedValue);
    }
    
    /**
     * @dev Verifies a standard Merkle proof for a balanced subtree
     * @param leaf The leaf node being proven
     * @param proof The Merkle proof (sibling hashes)
     * @return The calculated root of the balanced subtree
     */
    function verifyBalancedSubtree(
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash;
    }
    
    /**
     * @dev Creates an unhinged root from a list of balanced subtree roots
     * @param subtreeRoots Array of balanced subtree roots in canonical order
     * @return The unhinged root hash
     */
    function createUnhingedRoot(bytes32[] calldata subtreeRoots) internal pure returns (bytes32) {
        if (subtreeRoots.length == 0) {
            return bytes32(0);
        }
        
        bytes32 unhingedRoot = subtreeRoots[0];
        
        for (uint256 i = 1; i < subtreeRoots.length; i++) {
            unhingedRoot = keccak256(abi.encodePacked(unhingedRoot, subtreeRoots[i]));
        }
        
        return unhingedRoot;
    }
    
    /**
     * @dev Conversion function to create optimized proof from component parts
     * @param preHash Previous hashes combined (can be zero to indicate no preHash)
     * @param subtreeProof The balanced merkle proof
     * @param followingHashes The array of following hashes
     * @return optimizedProof The compact proof structure
     */
    function createOptimizedProof(
        bytes32 preHash,
        bytes32[] memory subtreeProof,
        bytes32[] memory followingHashes
    ) internal pure returns (UnhingedProof memory optimizedProof) {
        // Note: This function still uses memory parameters as it creates a new memory struct
        // Check if preHash is present (non-zero)
        bool hasPreHash = preHash != bytes32(0);
        
        // 1. Create the combined nodes array (size depends on whether preHash is included)
        uint256 nodesArraySize = subtreeProof.length + followingHashes.length;
        if (hasPreHash) {
            nodesArraySize += 1;
        }
        
        bytes32[] memory nodes = new bytes32[](nodesArraySize);
        
        // 2. Add preHash if present
        uint256 subtreeStartIndex = 0;
        if (hasPreHash) {
            nodes[0] = preHash;
            subtreeStartIndex = 1;
        }
        
        // 3. Add subtree proof nodes
        for (uint i = 0; i < subtreeProof.length; i++) {
            nodes[subtreeStartIndex + i] = subtreeProof[i];
        }
        
        // 4. Add following hash nodes
        for (uint i = 0; i < followingHashes.length; i++) {
            nodes[subtreeStartIndex + subtreeProof.length + i] = followingHashes[i];
        }
        
        // 5. Pack the counts with the hasPreHash flag
        bytes32 counts = packCounts(
            uint120(subtreeProof.length),
            uint120(followingHashes.length),
            hasPreHash
        );
        
        // 6. Create the optimized proof
        optimizedProof = UnhingedProof({
            nodes: nodes,
            counts: counts
        });
    }
}
```

## Applications

Unhinged Merkle Trees have applications in various cross-chain scenarios:

1. **Cross-Chain Permit Systems**: Allowing a single signature to authorize token operations across multiple chains
2. **Governance Systems**: Enabling single-signature voting across multiple chains
3. **Bridging Protocols**: Providing efficient verification of cross-chain transfers
4. **Distributed Identity**: Attesting to account ownership across chains
5. **Cross-Chain NFTs**: Proving ownership across multiple chains
6. **Layer 2 Rollups**: Creating compact proofs for multi-rollup systems

## Copyright

Copyright and related rights waived via [CC0](./LICENSE).