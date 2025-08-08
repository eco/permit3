# 🔏 Permit3 Cross-Chain Example 🌉

This example demonstrates how to use Permit3 to authorize token operations across multiple blockchains with a single signature.

## 🎬 Scenario

Let's implement a cross-chain DeFi position where you want to:

1. 💰 Provide 1000 USDC liquidity on Ethereum
2. 📉 Decrease an existing allowance on Arbitrum by 500 USDC
3. 🔒 Lock all token approvals on Optimism for security

All with a single signature.

## 1️⃣ Step 1: Define Chain-Specific Permits

First, define the operations for each chain:

```javascript
// Ethereum mainnet (Chain ID: 1) permits
const ethereumPermits = {
    chainId: 1,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours from now
        token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC on Ethereum
        account: "0xDEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1", // DEX on Ethereum
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC
    }]
};

// Arbitrum (Chain ID: 42161) permits
const arbitrumPermits = {
    chainId: 42161,
    permits: [{
        modeOrExpiration: 1, // Decrease mode
        token: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // USDC on Arbitrum
        account: "0xDEF2DEF2DEF2DEF2DEF2DEF2DEF2DEF2DEF2DEF2", // DEX on Arbitrum
        amountDelta: ethers.utils.parseUnits("500", 6) // Decrease by 500 USDC
    }]
};

// Optimism (Chain ID: 10) permits
const optimismPermits = {
    chainId: 10,
    permits: [{
        modeOrExpiration: 2, // Lock mode
        token: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // USDC on Optimism
        account: ethers.constants.AddressZero, // Not used for lock
        amountDelta: 0 // Not used for lock
    }]
};
```

## 2️⃣ Step 2: Generate Chain Hashes and Unbalanced Root

Generate the hash for each chain's permits, then combine them into the unbalanced root:

```javascript
// Generate root for each chain's permits
const ethHash = permit3.hashChainPermits(ethereumPermits);
const arbHash = permit3.hashChainPermits(arbitrumPermits);
const optHash = permit3.hashChainPermits(optimismPermits);

// Create the unbalanced merkle tree root
// Order matters, so we combine in order of chain ID
// Build merkle tree using standard approach
const leaves = [ethHash, arbHash, optHash];
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const merkleRoot = '0x' + merkleTree.getRoot().toString('hex');
```

## 3️⃣ Step 3: Create and Sign the Permit

```javascript
// Create salt, deadline, and timestamp
const salt = ethers.utils.randomBytes(32);
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
const timestamp = Math.floor(Date.now() / 1000);

// Define domain and types for EIP-712 signature
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1, // Use any chain ID for the signature
    verifyingContract: PERMIT3_ADDRESS
};

const types = {
    Permit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint48' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'merkleRoot', type: 'bytes32' }
    ]
};

// Create the value to sign
const value = {
    owner: ownerAddress,
    salt,
    deadline,
    timestamp,
    merkleRoot
};

// Sign the message
const signature = await signer._signTypedData(domain, types, value);
```

## 4️⃣ Step 4: Create Merkle Proofs for Each Chain

For each chain, generate a merkle proof that demonstrates its permits are part of the signed root:

```javascript
// Generate merkle proof for a specific leaf
function generateMerkleProof(leaves, targetIndex) {
    const proof = [];
    let currentIndex = targetIndex;
    let currentLevel = [...leaves];
    
    while (currentLevel.length > 1) {
        const pairs = [];
        
        for (let i = 0; i < currentLevel.length; i += 2) {
            const left = currentLevel[i];
            const right = currentLevel[i + 1] || currentLevel[i];
            
            // Track sibling for proof
            if (i === currentIndex || i + 1 === currentIndex) {
                const sibling = i === currentIndex ? right : left;
                proof.push(sibling);
                currentIndex = Math.floor(i / 2);
            }
            
            // Build next level
            const [first, second] = left < right ? [left, right] : [right, left];
            pairs.push(ethers.utils.keccak256(
                ethers.utils.defaultAbiCoder.encode(['bytes32', 'bytes32'], [first, second])
            ));
        }
        currentLevel = pairs;
    }
    
    return proof;
}

// On Ethereum (index 0)
const ethereumProof = {
    permits: ethereumPermits,
    proof: generateMerkleProof(leaves, 0)
};

// On Arbitrum (index 1)
const arbitrumProof = {
    permits: arbitrumPermits,
    proof: generateMerkleProof(leaves, 1)
};

// On Optimism (index 2)
const optimismProof = {
    permits: optimismPermits,
    proof: generateMerkleProof(leaves, 2)
};
```

## 5️⃣ Step 5: Execute on Each Chain

Final step is to submit the proof to each chain:

### 🔷 Ethereum Implementation

```solidity
// On Ethereum
const ethereumPermit3 = IPermit3.connect(PERMIT3_ADDRESS, ethereumProvider);

const ethereumTx = await ethereumPermit3.permit(
    ownerAddress,
    salt,
    deadline,
    timestamp,
    ethereumProof,
    signature
);

await ethereumTx.wait();
console.log("Ethereum transaction confirmed:", ethereumTx.hash);
```

### 🔹 Arbitrum Implementation

```solidity
// On Arbitrum
const arbitrumPermit3 = IPermit3.connect(PERMIT3_ADDRESS, arbitrumProvider);

const arbitrumTx = await arbitrumPermit3.permit(
    ownerAddress,
    salt,
    deadline,
    timestamp,
    arbitrumProof,
    signature
);

await arbitrumTx.wait();
console.log("Arbitrum transaction confirmed:", arbitrumTx.hash);
```

### 🔴 Optimism Implementation

```solidity
// On Optimism
const optimismPermit3 = IPermit3.connect(PERMIT3_ADDRESS, optimismProvider);

const optimismTx = await optimismPermit3.permit(
    ownerAddress,
    salt,
    deadline,
    timestamp,
    optimismProof,
    signature
);

await optimismTx.wait();
console.log("Optimism transaction confirmed:", optimismTx.hash);
```

## 🔍 Verification Process

When each chain receives its proof, the following verification happens under the hood:

1. For Ethereum:
   - Takes the USDC approval operation and hashes it
   - Verifies `ethereumProof` against the signed unbalanced root
   - Updates USDC allowance for DEX
   - Emits Permit and NonceUsed events

2. For Arbitrum:
   - Takes the USDC decrease operation and hashes it
   - Verifies `arbitrumProof` against the signed unbalanced root
   - Decreases USDC allowance for DEX
   - Emits Permit and NonceUsed events

3. For Optimism:
   - Takes the USDC lock operation and hashes it
   - Verifies `optimismProof` against the signed unbalanced root
   - Locks USDC allowances
   - Emits Permit and NonceUsed events

## 🔬 Advanced: Adding Balance Subtrees

For more complex cases with many operations per chain, you can use balanced Merkle trees for each chain:

```javascript
// Example with multiple operations per chain
const ethereumPermits = {
    chainId: 1,
    permits: [
        // Operation 1
        { modeOrExpiration: future, token: USDC, account: DEX1, amountDelta: 1000e6 },
        // Operation 2
        { modeOrExpiration: future, token: WETH, account: DEX2, amountDelta: 1e18 },
        // Operation 3 (...)        
    ]
};

// Create balanced tree for more complex proofs
const balancedTreeNodes = createBalancedTree(ethereumPermits.permits);
const balancedRoot = balancedTreeNodes[0];

// Generate proof for a specific operation within the tree
// For complex operations, you can include multiple operations in one chain's permits
// Each chain processes its operations independently while the merkle tree ensures integrity

// Build merkle tree with all chains
const allLeaves = [ethHash, arbHash, optHash];
const completeTree = new MerkleTree(allLeaves, keccak256, { sortPairs: true });

// Get proof for Ethereum (index 0)
const ethereumProof = {
    permits: ethereumPermits,
    proof: completeTree.getProof(ethHash).map(p => '0x' + p.data.toString('hex'))
};
```

## 🎯 Conclusion

This example demonstrates how Permit3 enables cross-chain operations with a single signature. The key advantages are:

1. 🛡️ **Security**: One signature controls operations across all chains
2. ⚡ **Gas Efficiency**: Each chain only needs to verify what's relevant to it
3. 🔄 **Flexibility**: Supports different operation types on each chain
4. 🧩 **Composability**: Works with any ERC20 token and spender contract

By using the Unbalanced Merkle tree methodology with standard merkle proofs, the system maintains security while minimizing gas costs for cross-chain verification.