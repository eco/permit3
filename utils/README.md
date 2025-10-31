# Permit3 Utilities

This directory contains utility functions and helpers for working with Permit3's tree-based cross-chain permit system.

## Files

### `permitNodeHelpers.js` (Primary Implementation)

**Core implementation for PermitNode tree construction and proof generation.**

This module provides the correct implementation of the tree flattening and proof generation algorithm that matches the on-chain Solidity reconstruction in `PermitNodeLib.sol`.

#### Core Hashing Functions
- `hashChainPermits(chainPermits)` - Hash a ChainPermits structure using EIP-712
- `hashPermitNode(permitNode)` - Recursively hash a PermitNode tree structure

#### Tree Encoding and Proof Generation
- `encodeProofStructure(permitNode, chainId)` - Generate proof and proofStructure encoding for a specific chain
- `buildProofForChain(permitNode, chainId)` - Extract just the proof array for a chain
- `findMerklePathToRoot(permitNode, chainId)` - Find the Merkle path from a leaf to root (core algorithm)

#### Tree Construction Utilities
- `buildOptimalPermitTree(chainPermitsArray)` - Build an optimal balanced binary tree from chain permits

#### Validation and Testing
- `validateProofStructure(permitNode)` - Validate that a tree follows binary tree constraints
- `verifyProofEncoding(permitNode, chainId, encoding)` - Verify off-chain encoding matches on-chain reconstruction
- `testTreeReconstruction(permitNode)` - Test all chains in a tree for correct reconstruction

#### Visualization
- `visualizeTree(permitNode)` - Create a human-readable tree diagram

#### Signing
- `signPermitNodePermit(...)` - Sign a PermitNode permit using EIP-712

### `merkle-helpers.js` (Legacy/Alternative)

Traditional Merkle tree utilities using `merkletreejs`. Includes functions for standard Merkle tree operations and the older nested structure approach.

**Note**: For new implementations, prefer `permitNodeHelpers.js` as it correctly implements the on-chain reconstruction algorithm.

## Core Concepts

### PermitNode Structure

```typescript
type PermitNode = {
    nodes: PermitNode[];     // Child nodes (nested structures)
    permits: ChainPermits[]; // Leaf chain permits
}

type ChainPermits = {
    chainId: number;
    permits: AllowanceOrTransfer[];
}
```

### Tree Reconstruction Algorithm

The on-chain `_reconstructPermitNodeHash()` function works as follows:

1. **Start** with `currentChainHash` (a ChainPermits leaf)
2. **Iterate** through the `proof` array, combining with each sibling
3. **Combine** based on type flags:
   - **Permit+Permit**: Use `_combinePermitAndPermit()` with alphabetical sort
   - **Node+Node**: Use `_combineNodeAndNode()` with alphabetical sort
   - **Node+Permit**: Use `_combineNodeAndPermit()` with struct order (NO sort)
4. **Result**: After first combination, current becomes a Node
5. **Return**: Final root hash

### Tree Structure Encoding (bytes32)

The `proofStructure` parameter encodes:
- **Byte 0 (bits 255-248)**: Position index (where current chain appears)
- **Bytes 1-31 (bits 247-0)**: Type flags (1 bit per proof element)
  - Bit i = 0: `proof[i]` is a Permit (ChainPermits leaf)
  - Bit i = 1: `proof[i]` is a Node (PermitNode)

## Usage Examples

### Example 1: Simple Two-Chain Tree

```javascript
const { encodeProofStructure, hashChainPermits, visualizeTree } = require('./permitNodeHelpers');

// Create chain permits
const chain1 = {
    chainId: 1,
    permits: [{ modeOrExpiration: 1000, tokenKey: '0x...', account: '0x...', amountDelta: 100 }]
};

const chain2 = {
    chainId: 42161,
    permits: [{ modeOrExpiration: 1000, tokenKey: '0x...', account: '0x...', amountDelta: 200 }]
};

// Build tree structure
const permitNode = {
    nodes: [],
    permits: [chain1, chain2]
};

// Visualize the tree
console.log(visualizeTree(permitNode));

// Generate proof for chain 1
const encoding = encodeProofStructure(permitNode, 1);
console.log('Proof Structure:', encoding.proofStructure);
console.log('Proof:', encoding.proof);
console.log('Current Chain Permits:', encoding.currentChainPermits);
```

### Example 2: Optimal Tree Construction

```javascript
const { buildOptimalPermitTree, testTreeReconstruction } = require('./permitNodeHelpers');

// Array of chain permits
const chainPermits = [
    { chainId: 1, permits: [...] },
    { chainId: 42161, permits: [...] },
    { chainId: 10, permits: [...] },
    { chainId: 137, permits: [...] }
];

// Build optimal balanced tree
const tree = buildOptimalPermitTree(chainPermits);

// Test all chains
const results = testTreeReconstruction(tree);
console.log(`Passed: ${results.passed}/${results.total}`);
```

### Example 3: Nested Structure (Node + Permit)

```javascript
// Create nested structure
const nestedTree = {
    nodes: [
        {
            nodes: [],
            permits: [
                { chainId: 1, permits: [...] },
                { chainId: 42161, permits: [...] }
            ]
        }
    ],
    permits: [
        { chainId: 10, permits: [...] }
    ]
};

// Verify all encodings work correctly
const results = testTreeReconstruction(nestedTree);
```

### Example 4: Validation

```javascript
const { validateProofStructure, verifyProofEncoding } = require('./permitNodeHelpers');

// Validate tree structure
const validation = validateProofStructure(permitNode);
if (!validation.valid) {
    console.error('Tree validation errors:', validation.errors);
}

// Verify specific encoding
const encoding = encodeProofStructure(permitNode, 1);
const isValid = verifyProofEncoding(permitNode, 1, encoding);
console.log('Encoding valid:', isValid);
```

## Testing

Run the comprehensive test suite:

```bash
node utils/test-permitNode.js
```

This tests:
- Simple two-chain trees
- Nested structures (Node+Permit)
- Complex structures (Node+Node)
- Optimal tree construction
- Edge cases (single chain)
- Proof path extraction
- Reconstruction verification

## Key Implementation Details

### Binary Tree Constraint

The implementation enforces binary trees (maximum 2 children per node) to match the on-chain reconstruction algorithm. Trees with more than 2 children will throw an error.

**Correct:**
```javascript
{ nodes: [], permits: [chain1, chain2] }  // 2 permits
{ nodes: [node1, node2], permits: [] }    // 2 nodes
{ nodes: [node1], permits: [chain1] }     // 1 node + 1 permit
```

**Incorrect:**
```javascript
{ nodes: [], permits: [chain1, chain2, chain3] }  // 3 permits - ERROR!
```

### Sorting Rules

- **Permit+Permit**: Hashes are sorted alphabetically before combining
- **Node+Node**: Hashes are sorted alphabetically before combining
- **Node+Permit**: NO sorting - struct order is preserved (nodes first)

### Type Definitions (TypeScript/JSDoc)

Full type definitions are included in the module for IDE autocomplete and documentation:

```typescript
@typedef {Object} AllowanceOrTransfer
@typedef {Object} ChainPermits
@typedef {Object} PermitNode
@typedef {Object} TreeStructureEncoding
@typedef {Object} MerklePathInfo
```

## Migration from Legacy Code

If you're using the old `flatten()` implementation from the original `permitNodeHelpers.js`, you need to:

1. **Understand the change**: The old implementation didn't correctly build Merkle paths
2. **Use new functions**: Replace direct calls to `flatten()` with `encodeProofStructure()`
3. **Validate**: Use `verifyProofEncoding()` to ensure proofs are correct
4. **Test**: Run `testTreeReconstruction()` on your trees

## Dependencies

- `ethers` (v6.x) - For Ethereum interactions and EIP-712 signing

## References

- **On-chain reconstruction**: `src/libraries/PermitNodeLib.sol` (lines 129-166)
- **On-chain hashing**: `src/Permit3.sol` (lines 536-556)
- **Test cases**: `test/PermitNodeReconstruction.t.sol`