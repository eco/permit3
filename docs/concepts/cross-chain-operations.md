<a id="cross-chain-operations-top"></a>
# 🔏 Permit3 Cross-Chain Operations 🌉

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Cross-Chain Operations

This document explains how Permit3 enables token operations across multiple blockchains with a single signature.

###### Navigation: [Overview](#overview) | [How It Works](#how-cross-chain-operations-work) | [Legacy Hash Chaining](#legacy-hash-chaining-mechanism) | [Unhinged Trees](#unhinged-merkle-tree-approach) | [Proof Structures](#proof-structures) | [Example](#example-cross-chain-token-approval) | [Chain Ordering](#chain-ordering-and-gas-optimization) | [Witness Functionality](#cross-chain-witness-functionality) | [Security](#security-considerations) | [Limitations](#limitations-and-considerations)

<a id="overview"></a>
## Overview

One of the most powerful features of Permit3 is the ability to authorize token operations across multiple blockchains with a single signature. This is achieved through the use of Unhinged Merkle Trees - a standard merkle tree implementation based on OpenZeppelin's MerkleProof library.

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
### Merkle Tree Construction

The merkle tree approach creates a single root hash that represents permit operations across multiple chains:

```
chainA_leaf = hash(chainA_permits)
chainB_leaf = hash(chainB_permits)
chainC_leaf = hash(chainC_permits)

// Build standard merkle tree
//        root
//       /    \
//     H1      chainC_leaf
//    /  \
// chainA  chainB
root = buildMerkleRoot([chainA_leaf, chainB_leaf, chainC_leaf])
```

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

This approach is gas-efficient as it contains only the essential merkle proof data needed for verification.

<a id="example-cross-chain-token-approval"></a>
## Example: Cross-Chain Token Approval

Let's walk through practical examples of setting up approvals on Ethereum, Arbitrum, and Optimism with a single signature using both approaches.

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

### Merkle Tree Approach

#### Step 2: Create Merkle Tree

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

// Build merkle tree and get root (typically done off-chain)
const leaves = [ethLeaf, arbLeaf, optLeaf];
const merkleRoot = buildMerkleRoot(leaves);
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
// Generate merkle proofs for each chain
// The proof contains sibling hashes needed to reconstruct the root

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

#### Step 5: Execute with Merkle Proofs

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
## Gas Optimization with Merkle Trees

Merkle trees provide predictable and efficient gas costs for cross-chain operations:

### Gas Characteristics

1. **Logarithmic Scaling**: Proof size grows as O(log n) with the number of operations
2. **Consistent Verification**: Each proof verification has predictable gas costs
3. **Compact Proofs**: Only sibling hashes are needed, minimizing calldata

### Example Gas Analysis

For a merkle tree with 8 chains:
- Each proof requires only 3 hashes (log₂(8) = 3)
- Total calldata per chain: 96 bytes (3 × 32 bytes)
- Verification complexity: O(log n) hash operations

This ensures that cross-chain operations remain gas-efficient even as the number of supported chains grows.

<a id="security-considerations"></a>
## Security Considerations

When working with cross-chain operations in Permit3, keep these security considerations in mind:

1. **Chain ID Validation**: Always verify the chain ID matches the current chain to prevent cross-chain replay attacks
2. **Salt Management**: Use unique salts for each signature to prevent replay attacks
3. **Deadline Validation**: Set reasonable deadlines to limit the window of vulnerability
4. **Timestamp Ordering**: Be aware of timestamp-based operation ordering across chains
5. **Proof Verification**: Ensure proofs correctly link chain-specific permits to the root hash

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