<a id="unhinged-merkle-tree-top"></a>
# 🔏 Permit3: Unhinged Merkle Trees 🌲

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Unhinged Merkle Trees

Unhinged Merkle Trees are a key innovation in Permit3 that enables efficient cross-chain proofs through an innovative two-part hybrid structure. This document explains what they are conceptually, how they work, and how they're implemented within the Permit3 system.

###### Navigation: [What Are They](#what-are-unhinged-merkle-trees) | [Why "Unhinged"](#why-unhinged) | [Key Structure](#key-structure-a-two-part-design) | [Working Together](#how-the-two-parts-work-together) | [Cross-Chain Use](#applied-to-cross-chain-use-cases) | [Gas Optimization](#gas-optimization-through-chain-ordering) | [Proof Structure](#proof-structure) | [Verification](#verification-process) | [Implementation](#implementation-in-permit3) | [Example](#example-cross-chain-permit-with-unhinged-merkle-tree) | [Benefits](#benefits-of-unhinged-merkle-trees) | [Applications](#applications-beyond-permit3) | [Comparison](#comparison-with-other-approaches) | [Conclusion](#conclusion)

<a id="what-are-unhinged-merkle-trees"></a>
## 🤔 What are Unhinged Merkle Trees?

Unhinged Merkle Trees are an innovative hybrid data structure that combines two complementary organizational principles: balanced merkle trees for efficient membership proofs and sequential hash chaining for optimal cross-chain linking. 

The key insight is the **two-part design**:
- **Bottom Part**: A balanced merkle tree that provides efficient O(log n) membership proofs
- **Top Part**: A sequential hash chain that efficiently links operations across multiple chains

While the current implementation uses standard merkle tree verification (built on OpenZeppelin's MerkleProof library), the conceptual foundation of the two-part structure guides the design philosophy and enables future optimizations.

<a id="why-unhinged"></a>
## 🏷️ Why "Unhinged"?

The name "Unhinged" reflects the deliberate deviation from traditional balanced merkle tree structures at the top level. In a standard merkle tree, every level maintains a balanced "hinged" structure. However, for cross-chain operations, this constraint becomes suboptimal.

The Unhinged Merkle Tree becomes "unhinged" from this balanced constraint at the top level:
- **Bottom stays "hinged"**: Maintains balanced structure for efficient membership proofs
- **Top becomes "unhinged"**: Uses sequential chaining optimized for cross-chain operations

This creates a more efficient structure for cross-chain applications while maintaining the benefits of balanced trees where they matter most.

<a id="key-structure-a-two-part-design"></a>
## 🧩 Key Structure: The Two-Part Hybrid Design

The conceptual foundation of Unhinged Merkle Trees is the innovative two-part hybrid structure:

```
               [H1] → [H2] → [H3] → ROOT  ← Sequential chain (top part)
            /      \      \      \
          [BR]    [D5]   [D6]   [D7]      ← Additional chain data
         /     \
     [BH1]     [BH2]                      ← Balanced tree (bottom part)
    /    \     /    \
  [D1]  [D2] [D3]  [D4]                   ← Leaf data
```

### Two-Part Structure:

1. 🔽 **Bottom Part - Balanced Merkle Tree**:
   - Maintains traditional balanced structure for efficient membership proofs
   - [BR] is the balanced root providing O(log n) verification
   - [BH1], [BH2] are balanced hash nodes
   - [D1]-[D4] are the leaf data points (individual operations)
   - Perfect for proving membership within a single chain's operations
   
2. 🔼 **Top Part - Sequential Hash Chain**:
   - Deviates from balanced structure for cross-chain optimization
   - Starts with balanced root [BR] as foundation
   - Incorporates additional data [D5], [D6], [D7] (other chain operations)  
   - Creates sequential chain: H1 = hash(BR, D5), H2 = hash(H1, D6), etc.
   - Optimized for gas efficiency across multiple chains

### Current Implementation

While the current implementation uses standard merkle tree verification for simplicity:
- Built on OpenZeppelin's proven MerkleProof library
- Uses ordered hashing (smaller value first) for consistency
- Provides O(log n) membership proofs
- Maintains security guarantees through battle-tested patterns

The conceptual two-part structure guides the design philosophy and enables future optimizations.

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
### Gas Optimization Through Chain Ordering

The two-part structure enables strategic gas optimization:

**Chain Ordering Strategy**:
- Place chains with cheaper calldata (L2s like Arbitrum, Optimism) earlier in the sequence
- Place chains with expensive calldata (Ethereum mainnet) at the end
- This minimizes proof size for expensive chains while allowing larger proofs on cheaper chains

**Benefits**:
1. **Sequential Efficiency**: Later chains in the sequence need smaller proofs
2. **Cost Optimization**: Heavy proof data processed on cheaper chains
3. **Predictable Gas Costs**: Verification complexity remains O(log n)
4. **Minimal Calldata**: Each proof contains only essential merkle proof data

**Current Implementation**:
The standard merkle tree approach provides:
- Consistent O(log n) verification complexity
- Minimal calldata requirements (log₂(n) hashes per proof)
- Gas-optimized verification through OpenZeppelin's implementation
- Future extensibility for chain ordering optimizations

<a id="proof-structure"></a>
## Proof Structure

The current implementation uses a simplified proof structure that maintains the benefits of the conceptual two-part design:

```solidity
struct UnhingedProof {
    bytes32[] nodes;    // Array of sibling hashes from leaf to root
}
```

This streamlined structure contains:

- **nodes**: An array of sibling hashes that form the merkle proof path
  - Each hash is a sibling node needed to reconstruct the path to the root
  - Follows standard merkle proof format for maximum compatibility
  - Number of nodes = ceiling(log₂(total leaves))
  - **Conceptual benefit**: Represents the efficient path through both parts of the hybrid structure

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

The simplified structure provides excellent gas efficiency while maintaining the conceptual benefits:

- **Minimal Calldata**: Only essential sibling hashes, no complex proof structures
- **No Overhead**: No packed counts or flags to decode
- **Predictable Costs**: Gas usage scales logarithmically with tree size
- **Optimized Verification**: Leverages OpenZeppelin's battle-tested implementation
- **Future-Ready**: Conceptual two-part foundation enables future optimizations
- **Chain Ordering Benefits**: Strategic ordering can minimize proof sizes on expensive chains

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

Permit3 implements Unhinged Merkle Trees through a clean architecture:

- `UnhingedMerkleTree.sol`: Implementation based on OpenZeppelin's MerkleProof library
- `IUnhingedMerkleTree.sol`: Simple interface defining the streamlined proof structure  
- Integration with `Permit3.sol` for cross-chain permit operations
- **Conceptual Foundation**: The two-part hybrid design guides the overall architecture

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

1. **Tree Construction** (Conceptual Two-Part Process):
   - **Bottom Part**: Collect operations within each chain, build balanced subtrees
   - **Top Part**: Chain the subtree roots sequentially for cross-chain linking
   - **Implementation**: Standard merkle tree built from all chain operations
   - The root represents operations across all chains with hybrid efficiency

2. **Signature Creation**:
   - The user signs the merkle root using EIP-712
   - Single signature leverages both balanced and sequential benefits
   - Authorizes operations across all chains efficiently

3. **Chain-Specific Verification**:
   - On each chain, verify the specific operations for that chain
   - Merkle proof connects local operations to the global signed root
   - **Conceptual benefit**: Proof traverses both balanced and sequential parts efficiently

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

1. **Conceptual Innovation**: Two-part hybrid structure optimized for cross-chain operations
2. **Gas Efficiency**: Strategic chain ordering minimizes costs on expensive chains
3. **Simplified User Experience**: One signature leverages both balanced and sequential benefits
4. **Flexible Structure**: Supports arbitrary numbers of chains and operations efficiently
5. **Security**: Standard merkle tree verification with battle-tested security properties
6. **Future Extensibility**: Conceptual foundation enables advanced optimizations
7. **Implementation Simplicity**: Current standard approach provides immediate benefits

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
| Traditional Balanced Trees | Well understood | Suboptimal for cross-chain gas costs |
| **Unhinged Merkle Trees** | Hybrid conceptual benefits + standard implementation security | None - best of both worlds |

<a id="conclusion"></a>
## Conclusion

Unhinged Merkle Trees represent an innovative conceptual breakthrough for cross-chain proof systems. The two-part hybrid structure—combining balanced merkle trees with sequential hash chaining—provides the theoretical foundation for optimal cross-chain operations.

The current implementation wisely leverages OpenZeppelin's proven MerkleProof library, providing immediate security and compatibility benefits while maintaining the door open for future optimizations guided by the conceptual framework.

Key advantages:
- **Conceptual Innovation**: Two-part structure optimized for cross-chain scenarios
- **Implementation Security**: Battle-tested standard merkle tree verification  
- **Gas Optimization Potential**: Chain ordering strategies minimize costs
- **Future Extensibility**: Conceptual foundation enables advanced optimizations

This approach enables a future where users can seamlessly authorize operations across the entire blockchain ecosystem with a single signature, while maintaining security through proven cryptographic primitives and the flexibility to implement advanced optimizations as the ecosystem evolves.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Nonce Management](/docs/concepts/nonce-management.md) | [Concepts](/docs/concepts/README.md) | [Witness Functionality](/docs/concepts/witness-functionality.md) |