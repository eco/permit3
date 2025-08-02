<a id="cross-chain-operations-top"></a>
# 🔏 Permit3 Cross-Chain Operations 🌉

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Cross-Chain Operations

This document explains how Permit3 enables token operations across multiple blockchains with a single signature.

###### Navigation: [Overview](#overview) | [How It Works](#how-cross-chain-operations-work) | [Legacy Hash Chaining](#legacy-hash-chaining-mechanism) | [Unhinged Trees](#unhinged-merkle-tree-approach) | [Proof Structures](#proof-structures) | [Example](#example-cross-chain-token-approval) | [Chain Ordering](#chain-ordering-and-gas-optimization) | [Witness Functionality](#cross-chain-witness-functionality) | [Security](#security-considerations) | [Limitations](#limitations-and-considerations)

<a id="overview"></a>
## Overview

One of the most powerful features of Permit3 is the ability to authorize token operations across multiple blockchains with a single signature. This is achieved through the use of Unhinged Merkle Trees - an innovative two-part hybrid structure that combines balanced merkle trees with sequential hash chaining, implemented using OpenZeppelin's proven MerkleProof library.

This approach allows different portions of a signed message to be verified and executed on different chains with optimal gas efficiency.

<a id="how-cross-chain-operations-work"></a>
## How Cross-Chain Operations Work

The cross-chain mechanism in Permit3 involves these key steps:

1. **Create Permits for Each Chain**: Define permit operations for each target blockchain
2. **Build Merkle Tree**: Hash each chain's permits and build a merkle tree from all leaves
3. **Signature Creation**: Sign the merkle root with the user's private key
4. **Generate Proofs**: Create a merkle proof for each chain's operations
5. **Execution**: Submit the proof and signature on each chain for verification and execution

<a id="legacy-hash-chaining-mechanism"></a>
### Unhinged Merkle Tree Construction

The Unhinged Merkle Tree approach leverages the conceptual two-part hybrid structure to create an efficient root hash representing operations across multiple chains:

**Conceptual Structure:**
```
               [H1] → [H2] → [H3] → ROOT  ← Sequential chain (top part)
            /      \      \      \
          [BR]    chainB  chainC  chainD   ← Chain data
         /     \
     [BH1]     [BH2]                      ← Balanced tree (bottom part)  
    /    \     /    \
chainA_ops1 chainA_ops2 ...               ← Operations within chainA
```

**Implementation:**
```
chainA_leaf = hash(chainA_permits)
chainB_leaf = hash(chainB_permits) 
chainC_leaf = hash(chainC_permits)

// Current implementation uses standard merkle tree
// guided by the two-part conceptual structure
//        root
//       /    \
//     H1      chainC_leaf
//    /  \
// chainA  chainB
root = buildMerkleRoot([chainA_leaf, chainB_leaf, chainC_leaf])
```

The conceptual two-part structure provides the foundation for gas optimization strategies such as strategic chain ordering.

<a id="unhinged-merkle-tree-approach"></a>
When executing on any specific chain, a merkle proof is provided that proves that chain's permits are included in the signed root. This uses standard merkle tree verification with ordered hashing (smaller value first) for consistency.

<a id="proof-structures"></a>
## Proof Structure

Permit3 uses a simple and efficient proof structure for cross-chain operations:

### UnhingedPermitProof Structure

```solidity
struct UnhingedPermitProof {
    ChainPermits permits;                              // Permit operations for the current chain
    IUnhingedMerkleTree.UnhingedProof unhingedProof;  // Merkle proof structure
}

// The simple UnhingedProof structure
struct UnhingedProof {
    bytes32[] nodes;    // Array of sibling hashes forming the merkle proof path
}
```

This approach is gas-efficient as it contains only the essential merkle proof data needed for verification, while the conceptual two-part structure enables strategic optimizations like chain ordering to minimize costs on expensive chains.

<a id="example-cross-chain-token-approval"></a>
## Example: Cross-Chain Token Approval

Let's walk through practical examples of setting up approvals on Ethereum, Arbitrum, and Optimism with a single signature using the Unhinged Merkle Tree approach.

### Step 1: Create Chain-Specific Permits

```javascript
// Ethereum permits
const ethPermits = {
    chainId: 1, // Ethereum
    permits: [
        {
            modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24-hour expiration
            token: "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI on Ethereum
            account: "0xDEF1...789", // Spender address
            amountDelta: ethers.utils.parseEther("100") // 100 DAI
        }
    ]
};

// Arbitrum permits
const arbPermits = {
    chainId: 42161, // Arbitrum
    permits: [
        {
            modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24-hour expiration
            token: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1", // DAI on Arbitrum
            account: "0xDEF1...789", // Spender address
            amountDelta: ethers.utils.parseEther("50") // 50 DAI
        }
    ]
};

// Optimism permits
const optPermits = {
    chainId: 10, // Optimism
    permits: [
        {
            modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24-hour expiration
            token: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1", // DAI on Optimism
            account: "0xDEF1...789", // Spender address
            amountDelta: ethers.utils.parseEther("25") // 25 DAI
        }
    ]
};
```

### Unhinged Merkle Tree Approach

#### Step 2: Create Unhinged Merkle Tree

```javascript
// Helper function to hash chain permits
function hashChainPermits(permits) {
    // Implementation details would depend on your environment
    // This should match the contract's hashChainPermits function
    return ethers.utils.keccak256(/* implementation */);
}

// Hash each chain's permits to create leaves
const ethLeaf = hashChainPermits(ethPermits);
const arbLeaf = hashChainPermits(arbPermits);
const optLeaf = hashChainPermits(optPermits);

// Build Unhinged Merkle Tree (guided by two-part conceptual structure)
// Implementation uses standard merkle tree for security and compatibility
const leaves = [ethLeaf, arbLeaf, optLeaf];
const unhingedRoot = buildMerkleRoot(leaves);

// Conceptual benefit: Chain ordering can optimize gas costs
// (e.g., place cheaper L2 chains first, expensive L1 chains last)
```

#### Step 3: Create and Sign Permit

```javascript
// Create permit data
const permitData = {
    owner: userAddress,
    salt: ethers.utils.randomBytes(32),
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    timestamp: Math.floor(Date.now() / 1000),
    unhingedRoot: merkleRoot
};

// Set up EIP-712 domain
const domain = {
    name: 'Permit3',
    version: '1',
    chainId: 0, // CROSS_CHAIN_ID for cross-chain operations
    verifyingContract: permit3Address
};

// Define types
const types = {
    SignedUnhingedPermit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'unhingedRoot', type: 'bytes32' }
    ]
};

// Sign the permit
const signature = await signer._signTypedData(domain, types, permitData);
```

#### Step 4: Create Merkle Proofs

```javascript
// Generate Unhinged Merkle Tree proofs for each chain  
// Each proof contains sibling hashes leveraging the two-part structure

// Ethereum proof (for leaf at index 0)
const ethProof = generateMerkleProof(leaves, 0);
const ethUnhingedProof = {
    permits: ethPermits,
    unhingedProof: {
        nodes: ethProof // Array of sibling hashes
    }
};

// Arbitrum proof (for leaf at index 1)
const arbProof = generateMerkleProof(leaves, 1);
const arbUnhingedProof = {
    permits: arbPermits,
    unhingedProof: {
        nodes: arbProof // Array of sibling hashes
    }
};

// Optimism proof (for leaf at index 2)
const optProof = generateMerkleProof(leaves, 2);
const optUnhingedProof = {
    permits: optPermits,
    unhingedProof: {
        nodes: optProof // Array of sibling hashes
    }
};
```

#### Step 5: Execute with Unhinged Proofs

```javascript
// On Ethereum
await permit3.permitUnhinged(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    ethUnhingedProof,
    signature
);

// On Arbitrum
await permit3.permitUnhinged(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    arbUnhingedProof,
    signature
);

// On Optimism
await permit3.permitUnhinged(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    optUnhingedProof,
    signature
);
```

<a id="cross-chain-witness-functionality"></a>
## Cross-Chain Witness Functionality

Permit3 also supports witness functionality in cross-chain operations, allowing you to include custom data in the signature verification process across multiple chains.

### Example with Witness Data

```javascript
// Create witness data and type string
const witness = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(['uint256'], [orderId])
);
const witnessTypeString = "Order order)Order(uint256 orderId)";

// Use permitWitness for witness functionality
await permit3.permitWitness(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    ethUnhingedProof, // Chain-specific merkle proof
    witness,
    witnessTypeString,
    signature
);
```

<a id="chain-ordering-and-gas-optimization"></a>
## Gas Optimization with Unhinged Merkle Trees

The two-part Unhinged Merkle Tree structure enables critical gas optimization for cross-chain operations through strategic chain ordering.

### Strategic Chain Ordering

To minimize overall transaction costs across all chains, you should order chains strategically based on their calldata costs:

1. **Lowest Cost Chains First**: Place chains with the lowest calldata/blob gas cost (typically L2s like Arbitrum, Optimism, etc.) at the beginning of the sequence
2. **Highest Cost Chains Last**: Place chains with the highest calldata/blob gas cost (like Ethereum mainnet) at the end of the sequence

### Why Chain Ordering Matters

This ordering strategy provides significant gas savings because:

- **Proof Size vs. Chain Position**: The conceptual structure of Unhinged Merkle Trees means that chains later in the sequence can leverage more efficient proof structures
- **Minimal Calldata on Expensive Chains**: While the current implementation uses standard merkle proofs, the conceptual framework enables future optimizations where expensive chains could use minimal proof data
- **Larger Proofs on Cheaper Chains**: The bulk of proof data can be processed on networks with lower calldata costs

### Concrete Gas Numbers

Consider a scenario with operations on Ethereum (high calldata cost) and two L2s (lower calldata cost):

**Without Optimization (Random Ordering):**
- Ethereum might require: 64+ bytes of expensive calldata for a full proof
- Total cost dominated by Ethereum's high gas prices

**With Strategic Ordering (L2s First, Ethereum Last):**
- L2s handle larger proofs where calldata is cheap
- Ethereum benefits from the conceptual structure with potential for minimal proof data
- Future optimizations could reduce Ethereum's proof to just 32 bytes
- **Potential savings: 50% or more on total cross-chain gas costs**

### Gas Characteristics

1. **Logarithmic Scaling**: Proof size grows as O(log n) with the number of operations
2. **Chain Ordering Benefits**: Strategic ordering minimizes costs on expensive chains
3. **Predictable Verification**: Each proof verification has consistent gas costs  
4. **Compact Proofs**: Only sibling hashes are needed, minimizing calldata
5. **Future Optimization Potential**: The two-part conceptual structure enables advanced gas optimizations

### Example Gas Analysis

For an Unhinged Merkle Tree with 8 chains:
- Each proof requires only 3 hashes (log₂(8) = 3)
- Base calldata per chain: 96 bytes (3 × 32 bytes)
- With strategic ordering:
  - Cheap L2 chains: Handle full 96-byte proofs economically
  - Expensive L1 (Ethereum): Positioned to benefit from future optimizations
- **Result**: Cross-chain operations become economically viable

This strategic approach ensures that cross-chain operations remain gas-efficient even as the ecosystem grows, with the innovative two-part structure providing a foundation for future optimizations.

<a id="security-considerations"></a>
## Security Considerations

When working with cross-chain operations in Permit3, keep these critical security considerations in mind:

### 1. **Chain ID Validation**
Chain ID verification is paramount for cross-chain security:
- **Always verify**: Each operation MUST validate `chainId` matches the executing network
- **Prevent replay attacks**: Without proper chain ID checks, signatures could be replayed on unintended networks
- **Implementation requirement**: Every permit includes the specific `chainId` in the signed data
- **Contract enforcement**: Permit3 automatically rejects operations with mismatched chain IDs

### 2. **Signature Domain Separation**
Proper domain separation prevents signature misuse:
- **EIP-712 domains**: Each signature includes chain-specific domain parameters
- **Cross-chain consideration**: When using `CROSS_CHAIN_ID` (0), signatures are intentionally valid across multiple chains
- **Explicit intent**: Users must understand whether they're signing for single-chain or cross-chain operations
- **Domain components**:
  ```solidity
  domain = {
      name: "Permit3",
      version: "1", 
      chainId: chainId, // Critical for domain separation
      verifyingContract: permit3Address
  }
  ```

### 3. **Nonce Management Across Chains**
Sophisticated nonce handling prevents replay attacks:
- **Salt-based system**: Each operation uses a unique salt that becomes permanently invalidated
- **Cross-chain coordination**: Same salt can be used across chains for atomic invalidation
- **Invalidation strategies**:
  - Single nonce: Invalidate one specific operation
  - Batch invalidation: Cancel multiple operations efficiently
  - Emergency lockdown: Invalidate all pending operations
- **State tracking**: Each chain independently tracks used nonces

### 4. **Additional Security Best Practices**
- **Deadline Validation**: Set reasonable deadlines to limit the window of vulnerability
- **Timestamp Ordering**: Be aware of timestamp-based operation ordering across chains
- **Proof Verification**: Ensure proofs correctly link chain-specific permits to the root hash
- **Witness validation**: When using witness data, ensure proper validation on each chain

<a id="limitations-and-considerations"></a>
## Limitations and Considerations

- **Atomicity**: Cross-chain operations are not atomic; each chain's operations execute independently
- **Timing**: Operations may execute at different times on different chains
- **Order Dependency**: If operations have dependencies across chains, consider the execution order
- **Gas Costs**: Merkle proofs have predictable O(log n) gas costs
- **Signature Reuse**: The same signature can be used on multiple chains, which can be a feature or a risk depending on your use case

## Conclusion

Cross-chain operations in Permit3 provide a powerful way to manage token permissions across multiple blockchains with a single signature. By understanding hash chaining, proof construction, and security considerations, you can build efficient and secure cross-chain applications.

The ability to authorize operations across chains with one signature significantly improves user experience and enables new use cases for cross-chain applications, making Permit3 a valuable tool for building the multi-chain future of DeFi.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Architecture](/docs/concepts/architecture.md) | [Concepts](/docs/concepts/README.md) | [Nonce Management](/docs/concepts/nonce-management.md) |