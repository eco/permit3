# Migration Guide: From Complex Proofs to Simple Merkle Trees

This guide helps you migrate from the old UnhingedProof structure to the new simplified merkle tree implementation.

## 🔄 What Changed?

### Old Structure (Complex)
```solidity
struct UnhingedProof {
    bytes32 counts;  // Packed metadata
    bytes32[] nodes; // Mixed array of preHash, subtreeProof, followingHashes
}
```

### New Structure (Simple)
```solidity
bytes32[] unhingedProof; // Just the merkle proof nodes
```

## 📋 Key Differences

| Feature | Old Implementation | New Implementation |
|---------|-------------------|-------------------|
| Proof Structure | Complex struct with counts | Simple bytes32[] array |
| Hashing | Sequential with preHash/following | Standard merkle tree |
| Verification | Custom algorithm | Standard merkle verification |
| Dependencies | Custom implementation | OpenZeppelin MerkleProof |
| Gas Cost | Higher due to complexity | Lower with optimized verification |

## 🛠️ Migration Steps

### Step 1: Update Your Imports

**Before:**
```javascript
// Custom helper functions
const createOptimizedProof = (preHash, subtreeProof, followingHashes) => {
    // Complex proof construction
};
```

**After:**
```javascript
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
```

### Step 2: Update Proof Generation

**Before:**
```javascript
// Old way - complex proof construction
const proofs = {};

chains.forEach((chain, index) => {
    if (index === 0) {
        // First chain
        const followingHashes = chains.slice(1).map(c => hashes[c]);
        proofs[chain] = {
            permits: chainPermits[chain],
            unhingedProof: createOptimizedProof(
                ethers.constants.HashZero,
                [],
                followingHashes
            )
        };
    } else if (index < chains.length - 1) {
        // Middle chains
        let preHash = hashes[chains[0]];
        for (let i = 1; i < index; i++) {
            preHash = hashLink(preHash, hashes[chains[i]]);
        }
        const followingHashes = chains.slice(index + 1).map(c => hashes[c]);
        proofs[chain] = {
            permits: chainPermits[chain],
            unhingedProof: createOptimizedProof(preHash, [], followingHashes)
        };
    } else {
        // Last chain
        let preHash = hashes[chains[0]];
        for (let i = 1; i < index; i++) {
            preHash = hashLink(preHash, hashes[chains[i]]);
        }
        proofs[chain] = {
            permits: chainPermits[chain],
            unhingedProof: createOptimizedProof(preHash, [], [])
        };
    }
});
```

**After:**
```javascript
// New way - standard merkle tree
const leaves = chains.map(chain => hashes[chain]);
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

const proofs = {};
chains.forEach((chain, index) => {
    proofs[chain] = {
        permits: chainPermits[chain],
        unhingedProof: merkleTree.getProof(leaves[index])
            .map(p => '0x' + p.data.toString('hex'))
    };
});
```

### Step 3: Update Root Calculation

**Before:**
```javascript
// Sequential hashing
let unhingedRoot = hashes[chains[0]];
for (let i = 1; i < chains.length; i++) {
    unhingedRoot = hashLink(unhingedRoot, hashes[chains[i]]);
}
```

**After:**
```javascript
// Merkle tree root
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const unhingedRoot = '0x' + merkleTree.getRoot().toString('hex');
```

### Step 4: Update Contract Interactions

The contract interface remains the same! The `permitUnhinged` function still accepts the same parameters:

```javascript
// This stays the same
await permit3.permitUnhinged(
    owner,
    salt,
    deadline,
    timestamp,
    proof, // Now contains simple bytes32[] in unhingedProof field
    signature
);
```

## 🔍 Common Patterns

### Single Chain Permit
No changes needed for single chain permits - they don't use UnhingedMerkleTree.

### Two Chain Permit
```javascript
// Before
const ethProof = {
    permits: ethPermits,
    unhingedProof: createOptimizedProof(
        ethers.constants.HashZero,
        [],
        [arbHash]
    )
};

const arbProof = {
    permits: arbPermits,
    unhingedProof: createOptimizedProof(
        ethHash,
        [],
        []
    )
};

// After
const leaves = [ethHash, arbHash];
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

const ethProof = {
    permits: ethPermits,
    unhingedProof: tree.getProof(ethHash).map(p => '0x' + p.data.toString('hex'))
};

const arbProof = {
    permits: arbPermits,
    unhingedProof: tree.getProof(arbHash).map(p => '0x' + p.data.toString('hex'))
};
```

### Multi-Chain Permit (3+ chains)
```javascript
// After - much simpler!
const leaves = [ethHash, arbHash, optHash, polyHash];
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = '0x' + tree.getRoot().toString('hex');

// Generate all proofs
const proofs = {};
['ethereum', 'arbitrum', 'optimism', 'polygon'].forEach((chain, i) => {
    proofs[chain] = {
        permits: chainPermits[chain],
        unhingedProof: tree.getProof(leaves[i]).map(p => '0x' + p.data.toString('hex'))
    };
});
```

## ⚠️ Important Notes

### Ordered Hashing
Always use `sortPairs: true` when creating the MerkleTree:
```javascript
new MerkleTree(leaves, keccak256, { sortPairs: true });
```

This ensures consistent ordering of nodes during hashing, matching the contract's verification logic.

### Leaf Order
While the merkle tree uses ordered hashing internally, you should still maintain consistent ordering of your chains (e.g., by chainId) for predictability:
```javascript
const orderedChains = Object.keys(chainPermits).sort((a, b) => 
    CHAIN_IDS[a] - CHAIN_IDS[b]
);
```

### Proof Format
The new `unhingedProof` is a simple array of sibling hashes:
```javascript
// Example proof for a 4-leaf tree
[
    '0x1234...', // Sibling at level 0
    '0x5678...'  // Sibling at level 1
]
```

## 🚀 Complete Migration Example

Here's a complete before/after example:

### Before (Complex)
```javascript
async function createCrossChainPermit(chainPermits, signer) {
    // Hash each chain's permits
    const hashes = {};
    const chains = Object.keys(chainPermits);
    
    for (const chain of chains) {
        hashes[chain] = await permit3.hashChainPermits(chainPermits[chain]);
    }
    
    // Calculate unhinged root (sequential)
    let unhingedRoot = hashes[chains[0]];
    for (let i = 1; i < chains.length; i++) {
        unhingedRoot = hashLink(unhingedRoot, hashes[chains[i]]);
    }
    
    // Create signature
    const signature = await signPermit(signer, unhingedRoot);
    
    // Generate complex proofs
    const proofs = {};
    chains.forEach((chain, index) => {
        // Complex logic for preHash and followingHashes
        // ... (50+ lines of code)
    });
    
    return { proofs, signature, unhingedRoot };
}
```

### After (Simple)
```javascript
async function createCrossChainPermit(chainPermits, signer) {
    // Hash each chain's permits
    const chains = Object.keys(chainPermits).sort();
    const leaves = [];
    
    for (const chain of chains) {
        const hash = await permit3.hashChainPermits(chainPermits[chain]);
        leaves.push(hash);
    }
    
    // Build merkle tree
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const unhingedRoot = '0x' + tree.getRoot().toString('hex');
    
    // Create signature
    const signature = await signPermit(signer, unhingedRoot);
    
    // Generate simple proofs
    const proofs = {};
    chains.forEach((chain, index) => {
        proofs[chain] = {
            permits: chainPermits[chain],
            unhingedProof: tree.getProof(leaves[index])
                .map(p => '0x' + p.data.toString('hex'))
        };
    });
    
    return { proofs, signature, unhingedRoot };
}
```

## 🎯 Benefits of Migration

1. **Simpler Code**: ~70% less code for proof generation
2. **Better Performance**: Standard merkle trees are well-optimized
3. **Easier Testing**: Can use standard merkle tree libraries for verification
4. **Lower Gas Costs**: Simplified verification on-chain
5. **Industry Standard**: Uses widely understood merkle tree concepts

## 🆘 Getting Help

If you encounter issues during migration:

1. Check that you're using `sortPairs: true`
2. Verify your leaves are hashed in the correct order
3. Use the debug utilities in `merkle-helpers.js`
4. Run tests with both old and new implementations to compare

The new implementation is backward compatible at the contract level - only the proof generation changes!