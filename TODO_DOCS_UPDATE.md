# Documentation Update TODO

The following documentation files need updating to reflect the simplified UnhingedMerkleTree implementation that now uses standard merkle proofs (`bytes32[]`) instead of the complex `UnhingedProof` struct:

## Files with `createOptimizedProof` function that need updating:

1. **docs/examples/integration-example.md**
   - Remove or update the `createOptimizedProof` utility function (lines 774-794)
   - Update all calls to this function to use standard merkle proof generation

2. **docs/examples/security-example.md**
   - Remove or update the `createOptimizedProof` utility function
   - Update proof generation examples

3. **docs/examples/cross-chain-example.md**
   - Update line 275 and similar to use standard merkle proofs

4. **docs/examples/allowance-management-example.md**
   - Update lines 269, 289 to use standard merkle proofs

5. **docs/guides/cross-chain-permit.md**
   - Update the complex proof generation example (lines 310-314)
   - Remove references to preHash, subtreeProof, followingHashes
   - Update to show standard merkle proof generation

## Key changes needed:

- Replace `createOptimizedProof(preHash, subtreeProof, followingHashes)` with standard merkle proof generation
- Remove references to the old proof structure fields (counts, preHash, subtreeProof, followingHashes)
- Update examples to show simple `bytes32[]` arrays for proofs
- Use standard merkle tree libraries (like OpenZeppelin's) in examples

## Example of the change:

Old:
```javascript
unhingedProof: createOptimizedProof(
    ethers.constants.HashZero,
    [],
    followingHashes
)
```

New:
```javascript
unhingedProof: generateMerkleProof(leaves, chainIndex)
```