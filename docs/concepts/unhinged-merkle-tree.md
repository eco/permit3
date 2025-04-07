# Unhinged Merkle Trees

Unhinged Merkle Trees are a key innovation in Permit3 that enables efficient cross-chain proofs while minimizing gas costs. This document explains what they are, how they work, and how they're used within the Permit3 system.

## What are Unhinged Merkle Trees?

Unhinged Merkle Trees are a hybrid data structure that combines two proven cryptographic patterns:

1. **Balanced Merkle Trees** at the bottom level for efficient inclusion proofs within a single chain
2. **Sequential Hash Chaining** at the top level for efficient cross-chain linking

This approach was specifically designed to solve the problem of cross-chain proofs while optimizing for gas efficiency, where each blockchain only needs to process what's relevant to it.

## Why "Unhinged"?

The name "Unhinged" refers to the deliberate deviation from traditional balanced Merkle trees at the top level. Unlike classic Merkle trees that maintain balance throughout, Unhinged Merkle Trees use an "unhinged" (sequential) structure at the top level to optimize for cross-chain verifications.

## Structure and Components

An Unhinged Merkle Tree consists of:

### 1. Balanced Subtrees

At the bottom level, each chain has its own balanced Merkle tree of operations:

```
           Root
          /    \
         /      \
      Node1    Node2
     /   \     /   \
   Leaf1 Leaf2 Leaf3 Leaf4
```

These follow standard Merkle tree construction rules where leaf nodes are paired and hashed recursively until a single root hash is obtained.

### 2. Unhinged Chain

The roots of the balanced subtrees are then chained sequentially through iterative hashing:

```
Chain1Root → Chain2Root → Chain3Root → ... → ChainNRoot
```

Where each arrow represents a hash operation:
```solidity
result = keccak256(abi.encodePacked(result, nextChainRoot));
```

## Proof Structure

Permits3 uses an optimized proof structure for Unhinged Merkle Trees:

```solidity
struct UnhingedProof {
    bytes32[] nodes;    // All nodes: [preHash (if present), subtreeProof nodes..., followingHashes...]
    bytes32 counts;     // Packed counts:
                        // - First 120 bits: subtreeProofCount (shifted 136 bits)
                        // - Next 120 bits: followingHashesCount (shifted 16 bits)
                        // - Next 15 bits: Reserved for future use
                        // - Last bit: hasPreHash flag (1 if present, 0 if not)
}
```

This compact representation contains three key components:

1. **preHash** (optional): The combined hash of all previous chain operations. Can be completely omitted to save gas when not needed.
2. **subtreeProof**: A traditional Merkle proof for the elements in the current chain's subtree
3. **followingHashes**: Array of subtree roots for chains that should be processed after the current chain

### Gas Optimization with hasPreHash Flag

The `hasPreHash` flag provides significant gas optimization by allowing proofs to completely omit the preHash when it's not needed, rather than including a zero bytes32 value. This results in:

- **Reduced calldata size**: Each omitted preHash saves 32 bytes of calldata, resulting in significant gas savings
- **Simplified verification flow**: When hasPreHash=false, verification starts directly with the subtree root
- **Lower transaction costs**: Particularly beneficial for the first chain in a sequence or for single-chain operations

Our benchmarks show significant gas savings on typical transactions using this optimization.

#### When to Use hasPreHash=false

You should set hasPreHash=false in these scenarios:
- For the first chain in a sequence (no previous chains to hash)
- For single-chain operations (no cross-chain verification needed)
- When optimizing for minimal calldata size and gas costs

#### When to Use hasPreHash=true

You should set hasPreHash=true in these scenarios:
- For chains in the middle or end of a sequence
- When verification depends on the combined hash of previous chains
- When preserving the complete verification path is important

## Verification Process

To verify that an element is included in an Unhinged Merkle Tree:

1. **Verify the balanced subtree proof**:
   - Use standard Merkle proof verification to check that the element is included in the current chain's subtree
   - Calculate the subtree root

2. **Recalculate the unhinged chain**:
   - If hasPreHash is true:
     - Start with `preHash` from nodes[0]
     - Append the calculated subtree root: `result = keccak256(abi.encodePacked(preHash, subtreeRoot))`
   - If hasPreHash is false:
     - Start directly with the subtree root: `result = subtreeRoot`
   - Sequentially append each following hash: `result = keccak256(abi.encodePacked(result, followingHash))`

3. **Verification**:
   - Compare the final calculated hash against the signed Unhinged Root
   - If they match, the proof is valid

## Implementation in Permit3

Permit3 implements Unhinged Merkle Trees through:

- `UnhingedMerkleTree.sol`: A library implementing the core functionality
- `IUnhingedMerkleTree.sol`: An interface defining the proof structure and verification methods
- Integration with `Permit3.sol` for cross-chain permit operations

The following functions are provided:

```solidity
// Verify a leaf is included in the unhinged merkle tree
function verify(
    bytes32 leaf,
    UnhingedProof memory proof,
    bytes32 unhingedRoot
) internal pure returns (bool)

// Verify a leaf is part of a balanced merkle subtree
function verifyBalancedSubtree(
    bytes32 leaf,
    bytes32[] memory proof
) internal pure returns (bytes32)

// Create an unhinged root from a list of balanced subtree roots
function createUnhingedRoot(bytes32[] memory subtreeRoots) internal pure returns (bytes32)

// Helper for extracting/packing counts
function extractCounts(bytes32 counts) internal pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash)
function packCounts(uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) internal pure returns (bytes32)
```

## Example: Cross-Chain Permit with Unhinged Merkle Tree

Here's how Unhinged Merkle Trees are used in a cross-chain permit scenario:

1. **Tree Construction**:
   - Create balanced Merkle trees for operations on each chain
   - Calculate the root hash for each tree
   - Chain these roots together to form the Unhinged Root

2. **Signature Creation**:
   - The user signs the Unhinged Root using EIP-712
   - This single signature authorizes operations across all chains

3. **Chain-Specific Verification**:
   - On each chain, only verify:
     - The specific operations for that chain
     - The connection to the Unhinged Root via the proof

### Code Example

```solidity
// Create permits for multiple chains
ChainPermits memory ethereumPermits = ChainPermits({
    chainId: 1,
    permits: [/* Ethereum permits */]
});

ChainPermits memory arbitrumPermits = ChainPermits({
    chainId: 42161,
    permits: [/* Arbitrum permits */]
});

// Create balanced Merkle trees and get roots
bytes32 ethereumRoot = hashChainPermits(ethereumPermits);
bytes32 arbitrumRoot = hashChainPermits(arbitrumPermits);

// Create the unhinged chain
bytes32[] memory roots = new bytes32[](2);
roots[0] = ethereumRoot;
roots[1] = arbitrumRoot;
bytes32 unhingedRoot = UnhingedMerkleTree.createUnhingedRoot(roots);

// Sign the unhinged root
bytes signature = signMessage(unhingedRoot);

// Later, on Arbitrum
UnhingedPermitProof memory proof = {
    permits: arbitrumPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethereumRoot,  // preHash (only Ethereum came before)
        [], // No subtree proof needed for the root
        []  // No following hashes
        // hasPreHash flag is automatically set to true since preHash is non-zero
    )
};

// Verify and process
permit3.permitUnhinged(owner, salt, deadline, timestamp, proof, signature);
```

## Benefits of Unhinged Merkle Trees

1. **Gas Efficiency**: Each chain only processes what's relevant to it
2. **Simplified User Experience**: One signature for operations across multiple chains
3. **Compact Proofs**: Optimized structure minimizes calldata costs
4. **Flexible Structure**: Supports arbitrary numbers of chains and operations
5. **Security**: Maintains cryptographic integrity across chain boundaries

## Applications Beyond Permit3

Unhinged Merkle Trees have applications beyond token approvals:

- Cross-chain NFT verification and transfers
- Multi-chain governance voting
- Cross-chain message passing systems
- Layer 2 rollup systems with shared state

## Comparison with Other Approaches

| Approach | Pros | Cons |
|----------|------|------|
| Separate Signatures | Simple implementation | Poor UX, multiple signatures required |
| Full Merkle Tree | Well-established pattern | Higher gas costs for cross-chain proofs |
| Hash Lists | Very simple | No efficient inclusion proofs |
| **Unhinged Merkle Trees** | Efficiency, flexibility, compact proofs | Novel approach (fewer existing implementations) |

## Conclusion

Unhinged Merkle Trees represent a significant innovation in cross-chain cryptographic proof systems. By combining the strengths of balanced Merkle trees and sequential hash chaining, they provide an optimal solution for cross-chain operations within Permit3.

The structure enables a future where users can seamlessly authorize operations across the entire blockchain ecosystem with a single signature, while maintaining security and minimizing gas costs.