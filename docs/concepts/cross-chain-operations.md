# Cross-Chain Operations in Permit3

This document explains how Permit3 enables token operations across multiple blockchains with a single signature.

## Overview

One of the most powerful features of Permit3 is the ability to authorize token operations across multiple blockchains with a single signature. This is achieved through two complementary techniques:

1. **Legacy Hash Chaining**: The original method that creates a sequential hash chain
2. **Unhinged Merkle Trees**: An optimized approach that combines balanced Merkle trees with sequential hash chaining

Both approaches allow different portions of a signed message to be verified and executed on different chains, with Unhinged Merkle Trees providing better gas efficiency.

## How Cross-Chain Operations Work

The cross-chain mechanism in Permit3 involves these key steps:

1. **Create Permits for Each Chain**: Define permit operations for each target blockchain
2. **Proof Structure Creation**: Combine the permit data using either hash chaining or Unhinged Merkle Trees
3. **Signature Creation**: Sign the root hash with the user's private key
4. **Cross-Chain Proof**: Create a proof for each chain that links the chain's permits to the root hash
5. **Execution**: Submit the proof and signature on each chain for verification and execution

### Legacy Hash Chaining Mechanism

The original hash chaining technique creates a single root hash that represents permit operations across multiple chains:

```
chainA_hash = hash(chainA_permits)
chainB_hash = hash(chainB_permits)
chainC_hash = hash(chainC_permits)

// Create an unbalanced hash chain
root_hash = hash(hash(hash(chainA_hash), chainB_hash), chainC_hash)
```

### Unhinged Merkle Tree Approach

The newer, more gas-efficient approach uses Unhinged Merkle Trees:

```
chainA_hash = hash(chainA_permits)
chainB_hash = hash(chainB_permits)
chainC_hash = hash(chainC_permits)

// Create balanced subtrees for each chain's operations
chainA_root = createBalancedMerkleRoot(chainA_operations)
chainB_root = createBalancedMerkleRoot(chainB_operations)
chainC_root = createBalancedMerkleRoot(chainC_operations)

// Chain the roots sequentially
unhinged_root = chainA_root
unhinged_root = hash(unhinged_root, chainB_root)
unhinged_root = hash(unhinged_root, chainC_root)
```

This root hash is what the user signs. When executing on any specific chain, a proof is provided that links that chain's permits to the root hash.

## Proof Structures

Permit3 offers two proof structures for cross-chain operations:

### Legacy Permit3Proof Structure

```solidity
struct Permit3Proof {
    bytes32 preHash;          // Hash of previous chain operations
    ChainPermits permits;     // Permit operations for the current chain
    bytes32[] followingHashes; // Hashes of subsequent chain operations
}
```

### Optimized UnhingedPermitProof Structure

```solidity
struct UnhingedPermitProof {
    ChainPermits permits;                  // Permit operations for the current chain
    IUnhingedMerkleTree.UnhingedProof unhingedProof;  // Optimized proof structure
}

// The optimized UnhingedProof structure
struct UnhingedProof {
    bytes32[] nodes;    // All nodes: [preHash, subtreeProof nodes..., followingHashes...]
    bytes32 counts;     // Packed counts (subtreeProofCount << 128 | followingHashesCount)
}
```

The Unhinged Merkle Tree approach is more gas-efficient as it packs data more compactly and optimizes verification.

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

### Legacy Hash Chain Approach

#### Step 2A: Create Hash Chain

```javascript
// Helper function to hash chain permits
function hashChainPermits(permits) {
    // Implementation details would depend on your environment
    // This should match the contract's hashChainPermits function
    return ethers.utils.keccak256(/* implementation */);
}

// Hash each chain's permits
const ethHash = hashChainPermits(ethPermits);
const arbHash = hashChainPermits(arbPermits);
const optHash = hashChainPermits(optPermits);

// Chain the hashes together (unbalanced Merkle tree)
const combinedHash1 = ethers.utils.keccak256(
    ethers.utils.solidityPack(['bytes32', 'bytes32'], [ethHash, arbHash])
);
const rootHash = ethers.utils.keccak256(
    ethers.utils.solidityPack(['bytes32', 'bytes32'], [combinedHash1, optHash])
);
```

#### Step 3A: Create and Sign Permit

```javascript
// Create permit data
const permitData = {
    owner: userAddress,
    salt: ethers.utils.randomBytes(32),
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    timestamp: Math.floor(Date.now() / 1000),
    unbalancedPermitsRoot: rootHash
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
    SignedPermit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'unbalancedPermitsRoot', type: 'bytes32' }
    ]
};

// Sign the permit
const signature = await signer._signTypedData(domain, types, permitData);
```

#### Step 4A: Create Chain-Specific Proofs

```javascript
// Ethereum proof
const ethProof = {
    preHash: ethers.constants.HashZero, // No previous chains
    permits: ethPermits,
    followingHashes: [arbHash, optHash] // Subsequent chain hashes
};

// Arbitrum proof
const arbProof = {
    preHash: ethHash, // Ethereum came before
    permits: arbPermits,
    followingHashes: [optHash] // Optimism comes after
};

// Optimism proof
const optProof = {
    preHash: ethers.utils.keccak256(
        ethers.utils.solidityPack(['bytes32', 'bytes32'], [ethHash, arbHash])
    ),
    permits: optPermits,
    followingHashes: [] // No subsequent chains
};
```

#### Step 5A: Execute on Each Chain

```javascript
// On Ethereum
await permit3.permit(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    ethProof,
    signature
);

// On Arbitrum
await permit3.permit(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    arbProof,
    signature
);

// On Optimism
await permit3.permit(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    optProof,
    signature
);
```

### Unhinged Merkle Tree Approach

#### Step 2B: Create Unhinged Merkle Tree

```javascript
// Hash each chain's permits
const ethHash = hashChainPermits(ethPermits);
const arbHash = hashChainPermits(arbPermits);
const optHash = hashChainPermits(optPermits);

// Create the unhinged chain
let unhingedRoot = ethHash;
unhingedRoot = ethers.utils.keccak256(
    ethers.utils.solidityPack(['bytes32', 'bytes32'], [unhingedRoot, arbHash])
);
unhingedRoot = ethers.utils.keccak256(
    ethers.utils.solidityPack(['bytes32', 'bytes32'], [unhingedRoot, optHash])
);
```

#### Step 3B: Create and Sign Unhinged Permit

```javascript
// Create permit data
const permitData = {
    owner: userAddress,
    salt: ethers.utils.randomBytes(32),
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    timestamp: Math.floor(Date.now() / 1000),
    unhingedRoot: unhingedRoot
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

#### Step 4B: Create Optimized Unhinged Proofs

```javascript
// Helper for packing counts
function packCounts(subtreeProofCount, followingHashesCount) {
    const packedValue = (BigInt(subtreeProofCount) << 128n) | BigInt(followingHashesCount);
    return ethers.utils.hexZeroPad(ethers.utils.hexlify(packedValue), 32);
}

// Ethereum proof
const ethUnhingedProof = {
    permits: ethPermits,
    unhingedProof: {
        nodes: [
            ethers.constants.HashZero, // preHash: No previous chains
            arbHash, optHash           // followingHashes: Arbitrum and Optimism come after
        ],
        counts: packCounts(0, 2)       // 0 subtree proofs, 2 following hashes
    }
};

// Arbitrum proof
const arbUnhingedProof = {
    permits: arbPermits,
    unhingedProof: {
        nodes: [
            ethHash,    // preHash: Ethereum came before
            optHash     // followingHashes: Optimism comes after
        ],
        counts: packCounts(0, 1) // 0 subtree proofs, 1 following hash
    }
};

// Optimism proof
const optUnhingedProof = {
    permits: optPermits,
    unhingedProof: {
        nodes: [
            ethers.utils.keccak256( // preHash: Combined hash of Ethereum and Arbitrum
                ethers.utils.solidityPack(['bytes32', 'bytes32'], [ethHash, arbHash])
            )
            // No following hashes
        ],
        counts: packCounts(0, 0) // 0 subtree proofs, 0 following hashes
    }
};
```

#### Step 5B: Execute with Unhinged Proofs

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

## Cross-Chain Witness Functionality

Permit3 also supports witness functionality in cross-chain operations, allowing you to include custom data in the signature verification process across multiple chains.

### Example with Witness Data

```javascript
// Create witness data and type string
const witness = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(['uint256'], [orderId])
);
const witnessTypeString = "Order order)Order(uint256 orderId)";

// Use witnessPermitTransferFrom instead of permit
await permit3.permitWitnessTransferFrom(
    permitData.owner,
    permitData.salt,
    permitData.deadline,
    permitData.timestamp,
    ethProof, // Chain-specific proof
    witness,
    witnessTypeString,
    signature
);
```

## Chain Ordering and Optimization

The order of chains in the hash chain matters for gas optimization. The most efficient approach is to order chains by the cost of calldata or blob gas:

1. **Lowest Cost Chains First**: Put chains with the lowest calldata/blob gas cost first in the hash chain
2. **Highest Cost Chains Last**: Put chains with the highest calldata/blob gas cost last in the hash chain

This minimizes the total gas cost across all chains, as earlier chains in the hash chain require more data in their proofs.

## Security Considerations

When working with cross-chain operations in Permit3, keep these security considerations in mind:

1. **Chain ID Validation**: Always verify the chain ID matches the current chain to prevent cross-chain replay attacks
2. **Salt Management**: Use unique salts for each signature to prevent replay attacks
3. **Deadline Validation**: Set reasonable deadlines to limit the window of vulnerability
4. **Timestamp Ordering**: Be aware of timestamp-based operation ordering across chains
5. **Proof Verification**: Ensure proofs correctly link chain-specific permits to the root hash

## Limitations and Considerations

- **Atomicity**: Cross-chain operations are not atomic; each chain's operations execute independently
- **Timing**: Operations may execute at different times on different chains
- **Order Dependency**: If operations have dependencies across chains, consider the execution order
- **Gas Costs**: Cross-chain proofs incur additional gas costs, especially for chains early in the hash chain
- **Signature Reuse**: The same signature can be used on multiple chains, which can be a feature or a risk depending on your use case

## Conclusion

Cross-chain operations in Permit3 provide a powerful way to manage token permissions across multiple blockchains with a single signature. By understanding hash chaining, proof construction, and security considerations, you can build efficient and secure cross-chain applications.

The ability to authorize operations across chains with one signature significantly improves user experience and enables new use cases for cross-chain applications, making Permit3 a valuable tool for building the multi-chain future of DeFi.