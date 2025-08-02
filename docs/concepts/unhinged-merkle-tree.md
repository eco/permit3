<a id="unhinged-merkle-tree-top"></a>
# 🔏 Permit3: Unhinged Merkle Trees 🌲

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Unhinged Merkle Trees

Unhinged Merkle Trees are a key innovation in Permit3 that enables efficient cross-chain proofs while minimizing gas costs. This document explains what they are, how they work, and how they're used within the Permit3 system.

###### Navigation: [What Are They](#what-are-unhinged-merkle-trees) | [Why "Unhinged"](#why-unhinged) | [Key Structure](#key-structure-a-two-part-design) | [Working Together](#how-the-two-parts-work-together) | [Cross-Chain Use](#applied-to-cross-chain-use-cases) | [Gas Optimization](#gas-optimization-through-chain-ordering) | [Proof Structure](#proof-structure) | [Verification](#verification-process) | [Implementation](#implementation-in-permit3) | [Example](#example-cross-chain-permit-with-unhinged-merkle-tree) | [Benefits](#benefits-of-unhinged-merkle-trees) | [Applications](#applications-beyond-permit3) | [Comparison](#comparison-with-other-approaches) | [Conclusion](#conclusion)

<a id="what-are-unhinged-merkle-trees"></a>
## 🤔 What are Unhinged Merkle Trees?

Unhinged Merkle Trees are a simplified merkle tree implementation optimized for cross-chain proofs. Built on top of OpenZeppelin's battle-tested MerkleProof library, they provide a standard merkle tree verification mechanism with ordered hashing (smaller value first).

This approach was specifically designed to solve the problem of cross-chain proofs while maintaining simplicity, security, and gas efficiency.

<a id="why-unhinged"></a>
## 🏷️ Why "Unhinged"?

The name "Unhinged" reflects the library's streamlined approach to merkle tree verification for cross-chain operations. While the name might suggest complexity, the implementation is actually a straightforward application of standard merkle tree patterns, making it both reliable and gas-efficient.

<a id="key-structure-a-two-part-design"></a>
## 🧩 Key Structure: Standard Merkle Trees

Unhinged Merkle Trees use the standard merkle tree structure familiar to all blockchain developers:

```
                    ROOT
                   /    \
                 H1      H2
                /  \    /  \
              H3   H4  H5   H6
             / \  / \ / \  / \
            D1 D2 D3 D4 D5 D6 D7 D8
```

Key characteristics:

1. 🔽 **Standard Binary Tree**:
   - Leaf nodes contain the actual data (permits, operations, etc.)
   - Internal nodes are hashes of their two children
   - Root node represents the entire tree
   
2. 🔼 **Ordered Hashing**:
   - When combining two nodes, the smaller value is placed first
   - This ensures consistent root calculation regardless of proof order
   - Based on OpenZeppelin's proven implementation

This approach provides:
- Efficient O(log n) membership proofs
- Standard, well-understood security properties
- Compatibility with existing merkle tree tooling

<a id="how-the-two-parts-work-together"></a>
## How It Works

1. **Tree Construction**:
   - Each chain's operations are hashed into leaf nodes
   - Leaves are paired and hashed to create parent nodes
   - Process continues until a single root is reached
   - The root represents all operations across all chains
   
2. **Proof Generation**:
   - To prove inclusion of a specific operation
   - Provide the sibling hashes along the path from leaf to root
   - These siblings allow reconstruction of the root
   - Typically requires log₂(n) hashes for n operations

<a id="applied-to-cross-chain-use-cases"></a>
## Applied to Cross-Chain Use Cases

In the cross-chain context:
- Each chain's operations form leaf nodes in the merkle tree
- All operations across all chains are included in a single tree
- The merkle root is what gets signed by the user

This allows each chain to:
1. Efficiently verify its own operations with a merkle proof
2. Trust that other chains' operations are included in the same root
3. Minimize gas usage with compact proofs (only log₂(n) hashes needed)

<a id="gas-optimization-through-chain-ordering"></a>
### Gas Optimization Strategies

While Unhinged Merkle Trees use standard merkle tree structures, there are still optimization opportunities:

- **Batch Operations**: Group multiple operations per chain to reduce the total number of leaves
- **Proof Caching**: Store commonly used proof paths to avoid recalculation
- **Efficient Encoding**: Use compact representations for leaf data

The standard merkle tree approach ensures:

1. **Predictable Gas Costs**: Proof verification has consistent O(log n) complexity
2. **Minimal Calldata**: Each proof only requires log₂(n) hashes
3. **Optimized Verification**: Leverages OpenZeppelin's gas-optimized implementation

By using proven merkle tree patterns, operations across multiple networks remain efficient and secure.

<a id="proof-structure"></a>
## Proof Structure

Permit3 uses a simplified proof structure for Unhinged Merkle Trees:

```solidity
struct UnhingedProof {
    bytes32[] nodes;    // Array of sibling hashes from leaf to root
}
```

This clean structure contains:

- **nodes**: An array of sibling hashes that form the merkle proof path
  - Each hash is a sibling node needed to reconstruct the path to the root
  - The order follows the standard merkle proof format
  - Number of nodes = ceiling(log₂(total leaves))

### How Merkle Proofs Work

To verify that a leaf is part of the tree:

1. Start with the leaf value (hash of the operation data)
2. For each proof node:
   - Combine the current hash with the proof node
   - Order them (smaller value first) and hash together
   - This gives you the parent node hash
3. Continue until you reach the root
4. Compare the calculated root with the expected root

### Gas Efficiency

The simplified structure provides excellent gas efficiency:

- **Minimal Calldata**: Only the essential sibling hashes are included
- **No Overhead**: No packed counts or flags to decode
- **Predictable Costs**: Gas usage scales logarithmically with tree size
- **Optimized Verification**: Uses OpenZeppelin's battle-tested implementation

<a id="verification-process"></a>
## Verification Process

To verify that an element is included in an Unhinged Merkle Tree:

1. **Calculate the leaf hash**:
   - Hash the operation data to get the leaf value
   - This represents the specific operation being verified

2. **Process the merkle proof**:
   - Start with the leaf hash
   - For each sibling hash in the proof:
     - Order the two hashes (smaller first)
     - Combine them: `parent = keccak256(abi.encodePacked(left, right))`
     - Move up to the next level

3. **Verification**:
   - Compare the final calculated hash against the signed root
   - If they match, the operation is proven to be part of the tree

<a id="implementation-in-permit3"></a>
## Implementation in Permit3

Permit3 implements Unhinged Merkle Trees through:

- `UnhingedMerkleTree.sol`: A library built on OpenZeppelin's MerkleProof
- `IUnhingedMerkleTree.sol`: A simple interface defining the proof structure
- Integration with `Permit3.sol` for cross-chain permit operations

The following functions are provided:

```solidity
// Verify a leaf is included in the merkle tree
function verify(
    UnhingedProof calldata proof,
    bytes32 unhingedRoot,
    bytes32 leaf
) internal pure returns (bool)

// Calculate the merkle root from a leaf and proof
function calculateRoot(
    UnhingedProof calldata proof,
    bytes32 leaf
) internal pure returns (bytes32)

// Alternative verification function for compatibility
function verifyProof(
    bytes32 root,
    bytes32 leaf,
    bytes32[] memory proof
) internal pure returns (bool)
```

<a id="example-cross-chain-permit-with-unhinged-merkle-tree"></a>
## Example: Cross-Chain Permit with Unhinged Merkle Tree

Here's how Unhinged Merkle Trees are used in a cross-chain permit scenario:

1. **Tree Construction**:
   - Collect all operations across all chains
   - Hash each operation to create leaf nodes
   - Build a standard merkle tree from all leaves
   - The root represents all operations

2. **Signature Creation**:
   - The user signs the merkle root using EIP-712
   - This single signature authorizes operations across all chains

3. **Chain-Specific Verification**:
   - On each chain, verify:
     - The specific operations for that chain
     - The merkle proof connecting to the signed root

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

// Hash each chain's permits to create leaves
bytes32 ethereumLeaf = hashChainPermits(ethereumPermits);
bytes32 arbitrumLeaf = hashChainPermits(arbitrumPermits);

// Build merkle tree and get root
// (This would typically be done off-chain)
bytes32[] memory leaves = new bytes32[](2);
leaves[0] = ethereumLeaf;
leaves[1] = arbitrumLeaf;
bytes32 merkleRoot = buildMerkleRoot(leaves);

// Sign the merkle root
bytes signature = signMessage(merkleRoot);

// Later, on Arbitrum
// Generate merkle proof for Arbitrum's leaf
bytes32[] memory arbitrumProof = generateMerkleProof(leaves, 1); // Index 1 for Arbitrum

UnhingedPermitProof memory proof = {
    permits: arbitrumPermits,
    unhingedProof: arbitrumProof
};

// Verify and process
permit3.permitUnhinged(owner, salt, deadline, timestamp, proof, signature);
```

<a id="benefits-of-unhinged-merkle-trees"></a>
## Benefits of Unhinged Merkle Trees

1. **Gas Efficiency**: Each chain only processes what's relevant to it
2. **Simplified User Experience**: One signature for operations across multiple chains
3. **Compact Proofs**: Optimized structure minimizes calldata costs
4. **Flexible Structure**: Supports arbitrary numbers of chains and operations
5. **Security**: Maintains cryptographic integrity across chain boundaries

<a id="applications-beyond-permit3"></a>
## Applications Beyond Permit3

Unhinged Merkle Trees have applications beyond token approvals:

- Cross-chain NFT verification and transfers
- Multi-chain governance voting
- Cross-chain message passing systems
- Layer 2 rollup systems with shared state

<a id="comparison-with-other-approaches"></a>
## Comparison with Other Approaches

| Approach | Pros | Cons |
|----------|------|------|
| Separate Signatures | Simple implementation | Poor UX, multiple signatures required |
| Hash Lists | Very simple | No efficient inclusion proofs |
| Complex Hybrid Trees | Potential gas optimizations | Increased complexity, harder to audit |
| **Unhinged Merkle Trees** | Standard, proven, efficient, simple | None - leverages battle-tested patterns |

<a id="conclusion"></a>
## Conclusion

Unhinged Merkle Trees provide a simple, secure, and efficient solution for cross-chain proof systems. By leveraging OpenZeppelin's proven MerkleProof library and standard merkle tree patterns, they offer reliability and gas efficiency without unnecessary complexity.

The implementation enables a future where users can seamlessly authorize operations across the entire blockchain ecosystem with a single signature, while maintaining security through time-tested cryptographic primitives.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Nonce Management](/docs/concepts/nonce-management.md) | [Concepts](/docs/concepts/README.md) | [Witness Functionality](/docs/concepts/witness-functionality.md) |