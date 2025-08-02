# 🔏 Permit3 Cross-Chain Permit Guide 🌉

This guide explains how to create and use cross-chain permits with Permit3, allowing users to authorize operations across multiple blockchains with a single signature.

## 🧠 Understanding Cross-Chain Permits

Cross-chain permits are designed to solve a key problem in multi-chain environments: requiring separate signatures for each blockchain. With Permit3, users can sign once and execute operations across any number of supported chains.

### 💡 Core Concepts

1. 🌲 **UnhingedMerkleTree**: A hybrid data structure combining:
   - A balanced Merkle tree for efficient per-chain data verification
   - A sequential hash chain for connecting across chains

2. 🔄 **Chain Ordering**: Chains are processed in a specific canonical order (typically by chain ID)

3. 🔍 **Proofs**: Each chain receives a specialized proof demonstrating that its operations are part of the signed root

4. 🧂 **Common Salt/Timestamp**: The same salt (nonce) and timestamp are used across all chains for correlation

## 🔧 Implementation Steps

### 1️⃣ Step 1: Define Chain-Specific Permits

Start by defining the operations you want to perform on each chain:

```javascript
// Ethereum mainnet permits
const ethereumPermits = {
    chainId: 1,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours
        token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
        account: "0x1111111111111111111111111111111111111111", // Spender
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC
    }]
};

// Arbitrum permits
const arbitrumPermits = {
    chainId: 42161,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours
        token: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // USDC on Arbitrum
        account: "0x2222222222222222222222222222222222222222", // Spender
        amountDelta: ethers.utils.parseUnits("500", 6) // 500 USDC
    }]
};

// Optimism permits
const optimismPermits = {
    chainId: 10,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours
        token: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // USDC on Optimism
        account: "0x3333333333333333333333333333333333333333", // Spender
        amountDelta: ethers.utils.parseUnits("200", 6) // 200 USDC
    }]
};
```

### 2️⃣ Step 2: Calculate Chain Hashes

Next, calculate a hash for each chain's permits using the `hashChainPermits` function:

```javascript
const Permit3 = new ethers.Contract(PERMIT3_ADDRESS, PERMIT3_ABI, provider);

// Calculate hashes for each chain
const ethereumHash = await Permit3.hashChainPermits(ethereumPermits);
const arbitrumHash = await Permit3.hashChainPermits(arbitrumPermits);
const optimismHash = await Permit3.hashChainPermits(optimismPermits);
```

### 3️⃣ Step 3: Create the Unhinged Root

Generate the unhinged root by sequentially linking the chain hashes in order of chain ID:

```javascript
// Import UnhingedMerkleTree utility
const UnhingedMerkleTree = {
    hashLink: (a, b) => ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'bytes32'],
            [a, b]
        )
    )
};

// Link hashes in order (chainId ascending)
const combinedHash1 = UnhingedMerkleTree.hashLink(ethereumHash, arbitrumHash);
const unhingedRoot = UnhingedMerkleTree.hashLink(combinedHash1, optimismHash);
```

### 4️⃣ Step 4: Sign the Unhinged Root

Create and sign an EIP-712 message containing the unhinged root:

```javascript
// Common parameters for all chains
const salt = ethers.utils.randomBytes(32); // Random salt (nonce)
const timestamp = Math.floor(Date.now() / 1000); // Current time
const deadline = timestamp + 3600; // 1 hour deadline

// Create EIP-712 domain (can use any chain for signature)
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1, // Using Ethereum for signing
    verifyingContract: PERMIT3_ADDRESS
};

// Define EIP-712 types
const types = {
    SignedPermit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'unhingedRoot', type: 'bytes32' }
    ]
};

// Create the message to sign
const value = {
    owner: wallet.address,
    salt,
    deadline,
    timestamp,
    unhingedRoot
};

// Sign the message
const signature = await wallet._signTypedData(domain, types, value);
```

### 5️⃣ Step 5: Create Chain-Specific Proofs

For each chain, create a specialized proof that connects it to the unhinged root:

```javascript
// Create optimized proof utility
function createOptimizedProof(preHash, subtreeProof, followingHashes) {
    // Note: preHash and subtreeProof are mutually exclusive
    const subtreeProofCount = subtreeProof.length;
    const followingHashesCount = followingHashes.length;
    const hasPreHash = preHash !== ethers.constants.HashZero;
    
    // Combine all bits into a packed bytes32
    let countValue = ethers.BigNumber.from(0);
    countValue = countValue.or(ethers.BigNumber.from(subtreeProofCount).shl(136)); // First 120 bits
    countValue = countValue.or(ethers.BigNumber.from(followingHashesCount).shl(16)); // Next 120 bits
    if (hasPreHash) countValue = countValue.or(1); // Last bit
    
    // Combine the nodes array
    const nodes = [];
    if (hasPreHash) nodes.push(preHash);
    nodes.push(...subtreeProof, ...followingHashes);
    
    return {
        nodes,
        counts: ethers.utils.hexZeroPad(countValue.toHexString(), 32)
    };
}

// Ethereum (first chain) proof
const ethereumProof = {
    permits: ethereumPermits,
    unhingedProof: createOptimizedProof(
        ethers.constants.HashZero, // No preHash for first chain
        [], // No subtree proof
        [arbitrumHash, optimismHash] // Following hashes
    )
};

// Arbitrum (middle chain) proof
const arbitrumProof = {
    permits: arbitrumPermits,
    unhingedProof: createOptimizedProof(
        ethereumHash, // preHash is Ethereum's hash
        [], // No subtree proof 
        [optimismHash] // Following hash
    )
};

// Optimism (last chain) proof
const optimismProof = {
    permits: optimismPermits,
    unhingedProof: createOptimizedProof(
        UnhingedMerkleTree.hashLink(ethereumHash, arbitrumHash), // preHash is the combined hash
        [], // No subtree proof
        [] // No following hashes for last chain
    )
};
```

### 6️⃣ Step 6: Execute on Each Chain

Finally, execute the permit on each chain using the appropriate proof:

```javascript
// On Ethereum
const ethereumTx = await ethereumPermit3.permit(
    wallet.address,
    salt,
    deadline,
    timestamp,
    ethereumProof,
    signature
);

// On Arbitrum
const arbitrumTx = await arbitrumPermit3.permit(
    wallet.address,
    salt,
    deadline,
    timestamp,
    arbitrumProof,
    signature
);

// On Optimism
const optimismTx = await optimismPermit3.permit(
    wallet.address,
    salt,
    deadline,
    timestamp,
    optimismProof,
    signature
);
```

## 🔬 Advanced Usage: Including Balanced Subtrees

For chains with many operations, you can use balanced Merkle trees to optimize gas usage:

```javascript
// Multiple operations on Ethereum
const ethereumComplexPermits = {
    chainId: 1,
    permits: [
        // Operation 1: Approve DEX A
        { modeOrExpiration: expiration, token: USDC, account: DEX_A, amountDelta: 1000e6 },
        // Operation 2: Approve DEX B
        { modeOrExpiration: expiration, token: WETH, account: DEX_B, amountDelta: 2e18 },
        // Operation 3: Approve DEX C
        { modeOrExpiration: expiration, token: DAI, account: DEX_C, amountDelta: 5000e18 }
    ]
};

// Create a balanced tree for the operations
function createBalancedTree(permits) {
    // Hash each permit
    const leaves = permits.map(permit => 
        ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ['uint48', 'address', 'address', 'uint160'],
                [permit.modeOrExpiration, permit.token, permit.account, permit.amountDelta]
            )
        )
    );
    
    // Build the tree layer by layer
    let currentLayer = leaves;
    while (currentLayer.length > 1) {
        const nextLayer = [];
        for (let i = 0; i < currentLayer.length; i += 2) {
            if (i + 1 < currentLayer.length) {
                // Hash the pair in sorted order
                const a = currentLayer[i];
                const b = currentLayer[i + 1];
                nextLayer.push(ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(
                        ['bytes32', 'bytes32'],
                        [a < b ? a : b, a < b ? b : a]
                    )
                ));
            } else {
                // Odd number of elements, promote the last one
                nextLayer.push(currentLayer[i]);
            }
        }
        currentLayer = nextLayer;
    }
    
    return currentLayer[0]; // Root hash
}

// Build a proof for a specific permit
function createBalancedProof(permits, index) {
    // Similar to createBalancedTree but generates a proof
    // This would return an array of sibling hashes needed for verification
    // ...implementation omitted for brevity...
}

// Create the balanced tree
const ethereumRoot = createBalancedTree(ethereumComplexPermits.permits);

// To prove a specific operation (e.g., operation index 1)
const operationProof = createBalancedProof(ethereumComplexPermits.permits, 1);

// Use in the unhinged proof
const ethereumComplexProof = {
    permits: ethereumComplexPermits,
    unhingedProof: createOptimizedProof(
        ethers.constants.HashZero, // No preHash for first chain
        operationProof, // Include the balanced subtree proof
        [arbitrumHash, optimismHash] // Following hashes
    )
};
```

## ⚡ Gas Optimization Tips

1. 🚫 **hasPreHash Flag**: For the first chain, omit the preHash by setting the flag to 0
2. 📊 **Chain Ordering**: Place the chains with most frequent operations first to reduce gas costs
3. 📦 **Batching**: Group multiple operations per chain to amortize the proof verification cost
4. 🧩 **Witness Combination**: For advanced use cases, combine witness functionality with cross-chain proofs

## 🔍 Verification Process

When a chain receives a cross-chain permit:

1. ✅ It first verifies that the chainId in the permit matches the current chain
2. 🧮 It calculates the hash of the current chain's permits
3. 📥 It retrieves preHash (if present) from the proof
4. 🔗 If preHash is present, it concatenates (preHash + currentHash), otherwise uses currentHash
5. ➕ It concatenates this result with each of the following hashes
6. 🔄 It compares the final result with the signed unhingedRoot
7. ✨ If matching, it processes the permits as authorized

## 🛡️ Security Considerations

1. 🔄 **Chain Consistency**: Use the same salt, deadline, and timestamp for all chains
2. ⚡ **Gas Estimation**: Cross-chain proofs use more gas than single-chain permits
3. 📋 **Order Dependency**: Operations must be executed in the correct chain order for consistent results
4. ⚠️ **Partial Execution**: Prepare for cases where execution fails on some chains but succeeds on others

## ⚠️ Error Handling

Common errors when working with cross-chain permits:

| Error | Cause | Solution |
|-------|-------|----------|
| 🚫 `WrongChainId` | Permit's chainId doesn't match blockchain | Verify correct proof is sent to each chain |
| ❌ `InvalidUnhingedProof` | Proof doesn't verify against root | Check chain order and hash calculations |
| ⏱️ `SignatureExpired` | Deadline has passed | Use longer deadlines for cross-chain operations |
| 🔢 `NonceAlreadyUsed` | Salt already used on this chain | Generate new salt and signatures |

## 🎯 Conclusion

Cross-chain permits provide a powerful way to authorize operations across multiple blockchains with a single signature. By following this guide, you can implement efficient and secure cross-chain token approvals in your application.

For more examples, see the [🌉 Cross-Chain Example](../examples/cross-chain-example.md) for a complete implementation.