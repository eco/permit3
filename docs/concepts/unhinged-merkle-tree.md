<a id="unhinged-merkle-tree-top"></a>
# 🔏 Permit3: Unhinged Merkle Trees 🌲

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Unhinged Merkle Trees

The Unhinged Merkle Tree methodology is a key approach used in Permit3 that enables efficient cross-chain proofs. This document explains what they are, how they work, and how they're implemented within the Permit3 system.

###### Navigation: [What Are They](#what-are-unhinged-merkle-trees) | [Why "Unhinged"](#why-unhinged) | [Key Structure](#key-structure-strategic-unbalancing) | [How It Works](#how-it-works) | [Cross-Chain Use](#applied-to-cross-chain-use-cases) | [Gas Optimization](#gas-optimization-through-chain-ordering) | [Proof Structure](#proof-structure) | [Verification](#verification-process) | [Implementation](#implementation-in-permit3) | [Example](#example-cross-chain-permit-with-unhinged-merkle-tree) | [Benefits](#benefits-of-unhinged-merkle-trees) | [Applications](#applications-beyond-permit3) | [Comparison](#comparison-with-other-approaches) | [Conclusion](#conclusion)

<a id="what-are-unhinged-merkle-trees"></a>
## 🤔 What are Unhinged Merkle Trees?

The Unhinged Merkle Tree methodology is an approach for structuring merkle trees that strategically unbalances the tree to optimize gas costs across different chains. 

The key insight is **strategic gas optimization**:
- **Expensive chains** (like Ethereum mainnet) are placed closer to the root for smaller proofs
- **Cheaper chains** (like L2s) can have longer proofs without significant cost impact

Uses merkle tree verification for security and compatibility.

<a id="why-unhinged"></a>
## 🏷️ Why "Unhinged"?

The name "Unhinged" reflects the deliberate breaking away from creating separate, isolated merkle trees for each chain. Instead of traditional separate trees per chain, the methodology creates a single "unhinged" tree that spans multiple chains.

The tree is strategically unbalanced to optimize gas costs:
- **Expensive chains** are positioned for shorter merkle proofs
- **Cheaper chains** can tolerate longer proofs without significant cost impact

This creates a more gas-efficient structure for cross-chain operations while using standard merkle tree verification.

<a id="key-structure-strategic-unbalancing"></a>
## 🧩 Key Structure: Strategic Unbalancing for Gas Optimization

The foundation of the Unhinged Merkle Tree methodology is strategic operation ordering:

```
                    ROOT
                   /    \
                  H1     H2        ← Expensive chains closer to root
                 / \    / \
               H3   H4 H5  H6      ← Mixed operations from all chains
              /|   |\ |\ |\
            Op1 Op2... Operations from all chains
```

### Strategic Positioning:

1. 🔽 **High-Cost Chains (e.g., Ethereum mainnet)**:
   - Positioned closer to the root
   - Require fewer proof elements (shorter paths)
   - Minimize calldata costs where gas is expensive
   - Example: Mainnet operations might need only 2-3 proof elements
   
2. 🔼 **Low-Cost Chains (e.g., L2s, sidechains)**:
   - Can be positioned deeper in the tree
   - Longer proofs are acceptable due to cheaper gas
   - Example: L2 operations might have 5-6 proof elements without significant cost impact

### How It Works

Unhinged Merkle Trees use merkle tree verification for simplicity:
- Uses ordered hashing (smaller value first) for consistency
- Provides O(log n) membership proofs
- Maintains security guarantees through battle-tested patterns

This strategic unbalancing guides the design philosophy and enables significant gas optimizations.

<a id="how-it-works"></a>
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

The strategic unbalancing enables significant gas optimization:

**Chain Ordering Strategy**:
- Place chains with expensive calldata (Ethereum mainnet) closer to the root
- Place chains with cheaper calldata (L2s like Arbitrum, Optimism) deeper in the tree
- This minimizes proof size for expensive chains while allowing larger proofs on cheaper chains

**Benefits**:
1. **Strategic Positioning**: Expensive chains positioned near root receive smaller proofs
2. **Cost Distribution**: Larger proofs handled by chains with cheaper calldata
3. **Proof Size Optimization**: Tree depth directly affects proof size requirements
4. **Minimal Calldata**: Chains near root need fewer sibling hashes in their proofs

The Unhinged Merkle Tree approach provides:
- Consistent O(log n) verification complexity
- Minimal calldata requirements (log₂(n) hashes per proof)
- Gas-optimized verification
- Future extensibility for chain ordering optimizations

<a id="proof-structure"></a>
## Proof Structure

The proof is simply a standard merkle proof array:

```solidity
bytes32[] unhingedProof;    // Standard merkle proof array of sibling hashes
```

When used in Permit3, it's part of the `UnhingedPermitProof` structure:

```solidity
struct UnhingedPermitProof {
    ChainPermits permits;      // Permit operations for the current chain
    bytes32[] unhingedProof;   // Array of sibling hashes forming the merkle proof
}
```

This streamlined approach:
- Uses standard `bytes32[]` arrays compatible with OpenZeppelin's MerkleProof
- Each hash is a sibling node needed to reconstruct the path to the root
- Number of nodes = ceiling(log₂(total leaves))
- **Key benefit**: Works directly with existing merkle proof libraries without custom structures

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

This structure provides excellent gas efficiency:

- **Minimal Calldata**: Only essential sibling hashes, no complex proof structures
- **No Overhead**: No packed counts or flags to decode
- **Predictable Costs**: Gas usage scales logarithmically with tree size
- **Optimized Verification**: Battle-tested approach
- **Future-Ready**: Two-part foundation enables future optimizations
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
## Usage in Permit3

Permit3 uses Unhinged Merkle trees through a clean architecture:

- OpenZeppelin's `MerkleProof.sol`: Standard merkle tree verification logic
- Integration directly with `Permit3.sol` for cross-chain permit operations
- **Foundation**: The strategic unbalancing methodology guides the overall architecture

The implementation uses OpenZeppelin's standard MerkleProof library:

```solidity
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Process a merkle proof to calculate the root
MerkleProof.processProof(
    bytes32[] memory proof,  // Standard merkle proof array
    bytes32 leaf             // The leaf to verify
) → bytes32                  // Returns the calculated root

// Calculate the merkle root from a leaf and proof
MerkleProof.processProof(
    bytes32[] memory proof,  // Standard merkle proof array
    bytes32 leaf             // The leaf node
) → bytes32                  // Returns the calculated root
```

<a id="example-cross-chain-permit-with-unhinged-merkle-tree"></a>
## Example: Cross-Chain Permit with Unhinged Merkle Tree

Here's how Unhinged Merkle Trees are used in a cross-chain permit scenario:

1. **Tree Construction** (Strategic Process):
   - **Operation Collection**: Gather operations from all chains
   - **Top Part**: Chain the subtree roots sequentially for cross-chain linking
   - **Result**: Standard merkle tree built from all chain operations
   - The root represents operations across all chains with hybrid efficiency

2. **Signature Creation**:
   - The user signs the merkle root using EIP-712
   - Single signature leverages both balanced and sequential benefits
   - Authorizes operations across all chains efficiently

3. **Chain-Specific Verification**:
   - On each chain, verify the specific operations for that chain
   - Merkle proof connects local operations to the global signed root
   - **Key benefit**: Proof traverses both balanced and sequential parts efficiently

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
permit3.permit(owner, salt, deadline, timestamp, proof, signature);
```

<a id="benefits-of-unhinged-merkle-trees"></a>
## Benefits of Unhinged Merkle Trees

1. **Design Innovation**: Two-part hybrid structure optimized for cross-chain operations
2. **Gas Efficiency**: Strategic chain ordering minimizes costs on expensive chains
3. **Better User Experience**: One signature leverages both balanced and sequential benefits
4. **Flexible Structure**: Supports arbitrary numbers of chains and operations efficiently
5. **Security**: Standard merkle tree verification with battle-tested security properties
6. **Future Extensibility**: Two-part foundation enables advanced optimizations
7. **Simplicity**: Standard approach provides immediate benefits

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
| **Unhinged Merkle Trees** | Hybrid design + standard security | None - best of both worlds |

<a id="conclusion"></a>
## Conclusion

The Unhinged Merkle Tree methodology represents a breakthrough for cross-chain proof systems. The strategic unbalancing approach—positioning expensive chains closer to the root for smaller proofs—provides the foundation for gas-optimal cross-chain operations.

Provides security and compatibility benefits through merkle tree verification.

Key advantages:
- **Design Innovation**: Strategic unbalancing optimized for cross-chain gas costs
- **Security**: Battle-tested merkle tree verification using standard libraries
- **Gas Optimization**: Expensive chains get smaller proofs through strategic positioning
- **Simplicity**: Uses standard merkle proof verification (OpenZeppelin's MerkleProof)

This approach enables a future where users can seamlessly authorize operations across the entire blockchain ecosystem with a single signature, while maintaining security through proven cryptographic primitives and the flexibility to implement advanced optimizations as the ecosystem evolves.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Nonce Management](/docs/concepts/nonce-management.md) | [Concepts](/docs/concepts/README.md) | [Witness Functionality](/docs/concepts/witness-functionality.md) |