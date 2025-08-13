# Cross-Chain Permit Guide

Learn how to use Permit3's Unbalanced Merkle tree for seamless cross-chain token operations.

## 🌐 Understanding Cross-Chain Permits

Cross-chain permits allow you to sign once and execute token operations across multiple chains. This is powered by the Unbalanced Merkle tree, which uses standard merkle proofs to efficiently verify permissions on each chain.

### Key Benefits

- ✍️ **Single Signature**: Sign once, execute everywhere
- ⛽ **Gas Efficient**: Each chain only processes its relevant data
- 🔒 **Secure**: Cryptographically proven with merkle trees
- 🚀 **Fast**: Parallel execution across chains

## 📦 Basic Cross-Chain Setup

### Step 1: Install Dependencies

```bash
npm install ethers merkletreejs keccak256
```

### Step 2: Create Permits for Each Chain

```javascript
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

// Define your permits for each chain
const permits = {
    ethereum: {
        chainId: 1,
        permits: [{
            modeOrExpiration: (BigInt(parseEther("100")) << 48n) | BigInt(expiration),
            token: USDC_MAINNET,
            account: spenderAddress
        }]
    },
    arbitrum: {
        chainId: 42161,
        permits: [{
            modeOrExpiration: (BigInt(parseEther("50")) << 48n) | BigInt(expiration),
            token: USDC_ARBITRUM,
            account: spenderAddress
        }]
    },
    optimism: {
        chainId: 10,
        permits: [{
            modeOrExpiration: (BigInt(parseEther("75")) << 48n) | BigInt(expiration),
            token: USDC_OPTIMISM,
            account: spenderAddress
        }]
    }
};
```

### Step 3: Build the Merkle Tree

```javascript
// Helper function to build merkle tree with ordered hashing
function buildMerkleTree(leaves) {
    return new MerkleTree(leaves, keccak256, { sortPairs: true });
}

// Hash each chain's permits
const leaves = [];
const chainToIndex = {};

const orderedChains = Object.keys(permits).sort(); // Consistent ordering

for (let i = 0; i < orderedChains.length; i++) {
    const chain = orderedChains[i];
    const permit3 = new ethers.Contract(PERMIT3_ADDRESS[chain], PERMIT3_ABI, provider[chain]);
    
    // Hash the chain permits
    const leaf = await permit3.hashChainPermits(permits[chain]);
    leaves.push(leaf);
    chainToIndex[chain] = i;
}

// Build the merkle tree
const merkleTree = buildMerkleTree(leaves);
const merkleRoot = '0x' + merkleTree.getRoot().toString('hex');
```

### Step 4: Sign the Root

```javascript
// Create signature
const salt = ethers.utils.randomBytes(32);
const timestamp = Math.floor(Date.now() / 1000);
const deadline = timestamp + 3600; // 1 hour validity

const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1, // Use mainnet for signing
    verifyingContract: PERMIT3_ADDRESS.ethereum
};

const types = {
    Permit3: [
        { name: "owner", type: "address" },
        { name: "salt", type: "bytes32" },
        { name: "deadline", type: "uint48" },
        { name: "timestamp", type: "uint48" },
        { name: "merkleRoot", type: "bytes32" }
    ]
};

const value = {
    owner: await signer.getAddress(),
    salt,
    deadline,
    timestamp,
    merkleRoot
};

const signature = await signer._signTypedData(domain, types, value);
```

### Step 5: Generate Proofs for Each Chain

```javascript
// Generate merkle proof for each chain
const proofs = {};

for (const chain of orderedChains) {
    const index = chainToIndex[chain];
    const leaf = leaves[index];
    const proof = merkleTree.getProof(leaf);
    
    proofs[chain] = {
        permits: permits[chain],
        proof: proof.map(p => '0x' + p.data.toString('hex'))
    };
}
```

### Step 6: Execute on Each Chain

```javascript
// Execute on Ethereum
const permit3Ethereum = new ethers.Contract(
    PERMIT3_ADDRESS.ethereum,
    PERMIT3_ABI,
    signerEthereum
);

await permit3Ethereum.permit(
    owner,
    salt,
    deadline,
    timestamp,
    proofs.ethereum,
    signature
);

// Execute on Arbitrum (in parallel)
const permit3Arbitrum = new ethers.Contract(
    PERMIT3_ADDRESS.arbitrum,
    PERMIT3_ABI,
    signerArbitrum
);

await permit3Arbitrum.permit(
    owner,
    salt,
    deadline,
    timestamp,
    proofs.arbitrum,
    signature
);
```

## 🎯 Advanced Patterns

### Multiple Operations Per Chain

When you have multiple operations on a single chain, include them all in the permits array:

```javascript
const ethereumPermits = {
    chainId: 1,
    permits: [
        {
            // Approve USDC for DEX
            modeOrExpiration: (BigInt(parseEther("1000")) << 48n) | BigInt(expiration),
            token: USDC_ADDRESS,
            account: DEX_ADDRESS
        },
        {
            // Approve WETH for Lending
            modeOrExpiration: (BigInt(parseEther("10")) << 48n) | BigInt(expiration),
            token: WETH_ADDRESS,
            account: LENDING_ADDRESS
        },
        {
            // Approve DAI for Yield Farm
            modeOrExpiration: (BigInt(parseEther("5000")) << 48n) | BigInt(expiration),
            token: DAI_ADDRESS,
            account: YIELD_FARM_ADDRESS
        }
    ]
};
```

### Dynamic Chain Selection

Build permits dynamically based on user's needs:

```javascript
class CrossChainPermitBuilder {
    constructor() {
        this.chainPermits = new Map();
    }
    
    addPermit(chain, token, spender, amount, expiration) {
        if (!this.chainPermits.has(chain)) {
            this.chainPermits.set(chain, {
                chainId: CHAIN_IDS[chain],
                permits: []
            });
        }
        
        const permit = {
            modeOrExpiration: (BigInt(amount) << 48n) | BigInt(expiration),
            token,
            account: spender
        };
        
        this.chainPermits.get(chain).permits.push(permit);
        return this;
    }
    
    async build(signer) {
        // Convert map to array and sort by chain
        const chains = Array.from(this.chainPermits.keys()).sort();
        const permits = {};
        const leaves = [];
        
        // Hash each chain's permits
        for (const chain of chains) {
            const chainData = this.chainPermits.get(chain);
            permits[chain] = chainData;
            
            const permit3 = new ethers.Contract(
                PERMIT3_ADDRESS[chain],
                PERMIT3_ABI,
                providers[chain]
            );
            
            const leaf = await permit3.hashChainPermits(chainData);
            leaves.push(leaf);
        }
        
        // Build merkle tree
        const merkleTree = buildMerkleTree(leaves);
        const root = '0x' + merkleTree.getRoot().toString('hex');
        
        // Create signature
        const salt = ethers.utils.randomBytes(32);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = timestamp + 3600;
        
        // ... (signing logic)
        
        // Generate proofs
        const proofs = {};
        chains.forEach((chain, index) => {
            const proof = merkleTree.getProof(leaves[index]);
            proofs[chain] = {
                permits: permits[chain],
                proof: proof.map(p => '0x' + p.data.toString('hex'))
            };
        });
        
        return { proofs, signature, salt, deadline, timestamp, root };
    }
}

// Usage
const builder = new CrossChainPermitBuilder();

builder
    .addPermit('ethereum', USDC_ETH, DEX_ADDRESS, parseEther('1000'), expiration)
    .addPermit('ethereum', WETH_ETH, LENDING_ADDRESS, parseEther('10'), expiration)
    .addPermit('arbitrum', USDC_ARB, DEX_ADDRESS, parseEther('500'), expiration)
    .addPermit('optimism', USDC_OPT, YIELD_ADDRESS, parseEther('2000'), expiration);

const crossChainPermit = await builder.build(signer);
```

## ⚡ Gas Optimization Tips

### 1. 📊 **Chain Ordering**
Order chains by frequency of use. Put the most frequently used chains first in the tree for slightly better proof sizes.

### 2. 📦 **Batching**
Group multiple operations per chain to amortize the verification cost:

```javascript
// Good: One permit with multiple operations
const batchedPermit = {
    chainId: 1,
    permits: [operation1, operation2, operation3]
};

// Less efficient: Multiple separate permits
// Would require multiple signatures and transactions
```

### 3. 🔧 **Proof Caching**
Cache merkle proofs when the same tree is used multiple times:

```javascript
class ProofCache {
    constructor() {
        this.cache = new Map();
    }
    
    getCacheKey(root, chainId) {
        return `${root}-${chainId}`;
    }
    
    set(root, chainId, proof) {
        this.cache.set(this.getCacheKey(root, chainId), proof);
    }
    
    get(root, chainId) {
        return this.cache.get(this.getCacheKey(root, chainId));
    }
}
```

### 4. 🧩 **Selective Execution**
Only execute on chains where you need the permissions immediately:

```javascript
// Execute only on chains with immediate needs
const urgentChains = ['ethereum', 'arbitrum'];
const deferredChains = ['optimism', 'polygon'];

// Execute urgent chains now
await Promise.all(
    urgentChains.map(chain => 
        executeOnChain(chain, proofs[chain], signature, salt, deadline, timestamp)
    )
);

// Save deferred chains for later
// The signature remains valid until the deadline
saveForLater(deferredChains, proofs, signature, salt, deadline, timestamp);
```

## 🔍 Verification Process

When a chain receives a cross-chain permit:

1. ✅ Verifies the chainId matches
2. ✅ Validates the signature against the unbalanced root
3. ✅ Verifies the merkle proof connecting the chain's permits to the root
4. ✅ Processes the permits if all checks pass

### Understanding Merkle Proof Verification

```javascript
// How the contract verifies your proof
function verifyMerkleProof(leaf, proof, root) {
    let computedHash = leaf;
    
    for (let i = 0; i < proof.length; i++) {
        const proofElement = proof[i];
        
        // Ordered hashing (smaller value first)
        if (computedHash <= proofElement) {
            computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
        } else {
            computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
        }
    }
    
    return computedHash == root;
}
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### "Invalid merkle proof"
- Ensure leaves are hashed in the same order when building the tree and generating proofs
- Verify you're using the same hashing function (keccak256)
- Check that `sortPairs: true` is set when creating the MerkleTree

#### "Wrong chain ID"
- Make sure the chainId in your permit matches the actual chain you're executing on
- Use the correct chainId constants (1 for Ethereum, 42161 for Arbitrum, etc.)

#### "Signature expired"
- Check that your deadline hasn't passed
- Ensure your system clock is synchronized
- Consider using longer deadlines for cross-chain operations

### Debugging Helper

```javascript
function debugCrossChainPermit(permits, merkleTree, proofs) {
    console.log("=== Cross-Chain Permit Debug ===");
    
    // Log tree structure
    console.log("Merkle Root:", '0x' + merkleTree.getRoot().toString('hex'));
    console.log("Tree Depth:", merkleTree.getDepth());
    
    // Log each chain's data
    Object.entries(permits).forEach(([chain, permit]) => {
        console.log(`\n${chain}:`);
        console.log("  Chain ID:", permit.chainId);
        console.log("  Permits:", permit.permits.length);
        console.log("  Proof Length:", proofs[chain].proof.length);
        
        // Verify proof locally
        const leaf = ethers.utils.keccak256(/* hash chain permits */);
        const valid = merkleTree.verify(
            proofs[chain].proof,
            leaf,
            merkleTree.getRoot()
        );
        console.log("  Local Verification:", valid ? "✅ PASS" : "❌ FAIL");
    });
}
```

## 📚 Complete Example

Here's a full working example of cross-chain permits:

```javascript
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

async function executeCrossChainPermits() {
    // Setup providers and signers
    const providers = {
        ethereum: new ethers.providers.JsonRpcProvider(ETH_RPC),
        arbitrum: new ethers.providers.JsonRpcProvider(ARB_RPC),
        optimism: new ethers.providers.JsonRpcProvider(OPT_RPC)
    };
    
    const signers = {
        ethereum: new ethers.Wallet(PRIVATE_KEY, providers.ethereum),
        arbitrum: new ethers.Wallet(PRIVATE_KEY, providers.arbitrum),
        optimism: new ethers.Wallet(PRIVATE_KEY, providers.optimism)
    };
    
    // Step 1: Create permits
    const expiration = Math.floor(Date.now() / 1000) + 86400; // 24 hours
    
    const permits = {
        ethereum: {
            chainId: 1,
            permits: [{
                modeOrExpiration: (BigInt(ethers.utils.parseEther("1000")) << 48n) | BigInt(expiration),
                token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
                account: "0x1111111111111111111111111111111111111111" // DEX
            }]
        },
        arbitrum: {
            chainId: 42161,
            permits: [{
                modeOrExpiration: (BigInt(ethers.utils.parseEther("500")) << 48n) | BigInt(expiration),
                token: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // USDC.e
                account: "0x2222222222222222222222222222222222222222" // Lending
            }]
        },
        optimism: {
            chainId: 10,
            permits: [{
                modeOrExpiration: (BigInt(ethers.utils.parseEther("750")) << 48n) | BigInt(expiration),
                token: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // USDC
                account: "0x3333333333333333333333333333333333333333" // Yield
            }]
        }
    };
    
    // Step 2: Hash permits and build merkle tree
    const chains = Object.keys(permits).sort();
    const leaves = [];
    
    for (const chain of chains) {
        const permit3 = new ethers.Contract(
            PERMIT3_ADDRESS[chain],
            PERMIT3_ABI,
            providers[chain]
        );
        
        const leaf = await permit3.hashChainPermits(permits[chain]);
        leaves.push(leaf);
    }
    
    const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const merkleRoot = '0x' + merkleTree.getRoot().toString('hex');
    
    // Step 3: Create signature
    const owner = await signers.ethereum.getAddress();
    const salt = ethers.utils.randomBytes(32);
    const timestamp = Math.floor(Date.now() / 1000);
    const deadline = timestamp + 3600;
    
    const domain = {
        name: "Permit3",
        version: "1",
        chainId: 1,
        verifyingContract: PERMIT3_ADDRESS.ethereum
    };
    
    const types = {
        Permit3: [
            { name: "owner", type: "address" },
            { name: "salt", type: "bytes32" },
            { name: "deadline", type: "uint48" },
            { name: "timestamp", type: "uint48" },
            { name: "merkleRoot", type: "bytes32" }
        ]
    };
    
    const value = { owner, salt, deadline, timestamp, merkleRoot };
    const signature = await signers.ethereum._signTypedData(domain, types, value);
    
    // Step 4: Generate proofs
    const proofs = {};
    chains.forEach((chain, index) => {
        const proof = merkleTree.getProof(leaves[index]);
        proofs[chain] = {
            permits: permits[chain],
            proof: proof.map(p => '0x' + p.data.toString('hex'))
        };
    });
    
    // Step 5: Execute on all chains
    const executions = chains.map(async (chain) => {
        const permit3 = new ethers.Contract(
            PERMIT3_ADDRESS[chain],
            PERMIT3_ABI,
            signers[chain]
        );
        
        console.log(`Executing on ${chain}...`);
        
        const tx = await permit3.permit(
            owner,
            salt,
            deadline,
            timestamp,
            proofs[chain],
            signature
        );
        
        const receipt = await tx.wait();
        console.log(`✅ ${chain} complete: ${receipt.transactionHash}`);
        
        return { chain, tx: receipt.transactionHash };
    });
    
    const results = await Promise.all(executions);
    console.log("🎉 All chains complete!", results);
    
    return results;
}

// Run the example
executeCrossChainPermits().catch(console.error);
```

## 🎓 Key Takeaways

1. **Unbalanced Merkle tree methodology uses standard merkle proofs** - Simple `bytes32[]` arrays with OpenZeppelin's MerkleProof.processProof()
2. **Sign once, execute anywhere** - One signature works across all chains
3. **Order matters** - Keep chain ordering consistent
4. **Gas efficient** - Each chain only verifies its own proof
5. **Flexible** - Add as many chains and operations as needed

The merkle tree approach makes cross-chain permits easy to understand and implement while maintaining security and efficiency.