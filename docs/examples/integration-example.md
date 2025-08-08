# Integration Example

This example demonstrates how to integrate Permit3 into a decentralized application, showing how different components interact to create a complete user experience.

## Full Stack Integration

We'll build a complete integration from frontend to smart contracts, using Permit3 to enable a seamless token approval and transfer flow.

### Frontend Components

Start by implementing a React component for permit creation:

```jsx
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import { PERMIT3_ABI } from './abis'; // Import your ABI definitions

// Token Approval Component
const TokenApproval = () => {
    const [loading, setLoading] = useState(false);
    const [amount, setAmount] = useState('0');
    const [token, setToken] = useState('');
    const [spender, setSpender] = useState('');
    const [expiration, setExpiration] = useState(24); // Hours
    const [success, setSuccess] = useState(false);
    const [error, setError] = useState(null);

    // Constants
    const PERMIT3_ADDRESS = "0x0000000000000000000000000000000000000000"; // Replace with actual address
    const TOKENS = [
        { address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", symbol: "USDC", decimals: 6 },
        { address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", symbol: "WETH", decimals: 18 },
        { address: "0x6B175474E89094C44Da98b954EedeAC495271d0F", symbol: "DAI", decimals: 18 },
    ];
    
    const SPENDERS = [
        { address: "0x1111111111111111111111111111111111111111", name: "DEX A" },
        { address: "0x2222222222222222222222222222222222222222", name: "Lending Protocol B" },
        { address: "0x3333333333333333333333333333333333333333", name: "Yield Aggregator C" },
    ];

    // Connect to provider
    async function getProvider() {
        if (window.ethereum) {
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            return new ethers.providers.Web3Provider(window.ethereum);
        }
        throw new Error("No web3 provider detected");
    }

    // Create a permit
    async function createPermit() {
        setLoading(true);
        setError(null);
        
        try {
            const provider = await getProvider();
            const signer = provider.getSigner();
            const permit3 = new ethers.Contract(PERMIT3_ADDRESS, PERMIT3_ABI, signer);
            
            const selectedToken = TOKENS.find(t => t.address === token);
            if (!selectedToken) throw new Error("Invalid token");
            
            // Calculate amount with decimals
            const parsedAmount = ethers.utils.parseUnits(amount, selectedToken.decimals);
            
            // Calculate expiration timestamp
            const expirationTimestamp = Math.floor(Date.now() / 1000) + (expiration * 3600);
            
            // Build permit data
            const permitData = {
                token: token,
                amount: parsedAmount,
                expiration: expirationTimestamp,
                spender: spender
            };
            
            // Create permit with Permit3
            const tx = await permit3.permit(
                await signer.getAddress(),
                permitData.token,
                permitData.amount,
                permitData.expiration,
                permitData.spender
            );
            
            await tx.wait();
            setSuccess(true);
            
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="permit-approval">
            <h2>Create Token Permit</h2>
            
            <div className="form-group">
                <label>Token:</label>
                <select value={token} onChange={e => setToken(e.target.value)}>
                    <option value="">Select a token</option>
                    {TOKENS.map(t => (
                        <option key={t.address} value={t.address}>{t.symbol}</option>
                    ))}
                </select>
            </div>
            
            <div className="form-group">
                <label>Amount:</label>
                <input 
                    type="number" 
                    value={amount} 
                    onChange={e => setAmount(e.target.value)}
                    placeholder="0.0"
                />
            </div>
            
            <div className="form-group">
                <label>Spender:</label>
                <select value={spender} onChange={e => setSpender(e.target.value)}>
                    <option value="">Select a spender</option>
                    {SPENDERS.map(s => (
                        <option key={s.address} value={s.address}>{s.name}</option>
                    ))}
                </select>
            </div>
            
            <div className="form-group">
                <label>Expiration (hours):</label>
                <input 
                    type="number" 
                    value={expiration} 
                    onChange={e => setExpiration(e.target.value)}
                    min="1"
                    max="720"
                />
            </div>
            
            <button onClick={createPermit} disabled={loading || !token || !spender}>
                {loading ? 'Creating...' : 'Create Permit'}
            </button>
            
            {success && (
                <div className="success">Permit created successfully!</div>
            )}
            
            {error && (
                <div className="error">Error: {error}</div>
            )}
        </div>
    );
};
```

### Backend Service for Cross-Chain Permits

Here's a Node.js service that coordinates cross-chain permits using Unbalanced Merkle tree:

```javascript
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

// Merkle Tree Helper Class
class MerkleTreeHelper {
    // Build merkle tree with ordered hashing
    static buildTree(leaves) {
        // Use ordered hashing for consistency
        const hashFn = (data) => {
            if (Buffer.isBuffer(data)) return data;
            return Buffer.from(ethers.utils.keccak256(data).slice(2), 'hex');
        };
        
        const tree = new MerkleTree(leaves, hashFn, { 
            sortPairs: true  // This ensures ordered hashing
        });
        
        return tree;
    }
    
    // Generate proof for a specific leaf
    static getProof(tree, leaf) {
        const proof = tree.getProof(leaf);
        // Convert to bytes32[] format expected by the contract
        return proof.map(p => '0x' + p.data.toString('hex'));
    }
    
    // Get the merkle root
    static getRoot(tree) {
        return '0x' + tree.getRoot().toString('hex');
    }
}

// Cross-Chain Coordinator Service
class CrossChainCoordinator {
    constructor() {
        this.chains = {
            ethereum: {
                chainId: 1,
                rpc: 'https://eth.llamarpc.com',
                permit3Address: '0x0000000000000000000000000000000000000000'
            },
            arbitrum: {
                chainId: 42161,
                rpc: 'https://arb1.arbitrum.io/rpc',
                permit3Address: '0x0000000000000000000000000000000000000000'
            },
            optimism: {
                chainId: 10,
                rpc: 'https://mainnet.optimism.io',
                permit3Address: '0x0000000000000000000000000000000000000000'
            }
        };
        
        this.providers = {};
        this.permit3Contracts = {};
        this.permits = {};
        
        this.initializeProviders();
    }
    
    // Initialize providers and contracts
    initializeProviders() {
        Object.entries(this.chains).forEach(([chainName, config]) => {
            this.providers[chainName] = new ethers.providers.JsonRpcProvider(config.rpc);
            this.permit3Contracts[chainName] = new ethers.Contract(
                config.permit3Address,
                PERMIT3_ABI,
                this.providers[chainName]
            );
        });
    }
    
    // Add a permit for a specific chain
    addChainPermit(chainName, permitData) {
        if (!this.chains[chainName]) {
            throw new Error(`Chain ${chainName} not configured`);
        }
        
        this.permits[chainName] = permitData;
    }
    
    // Generate the cross-chain permit with standard merkle tree
    async generateCrossChainPermit(wallet) {
        // Ensure we have all required data
        const chainNames = Object.keys(this.permits);
        if (chainNames.length === 0) {
            throw new Error("No chain permits configured");
        }
        
        // Order chains by chainId for consistency
        const orderedChains = chainNames.sort(
            (a, b) => this.chains[a].chainId - this.chains[b].chainId
        );
        
        // Generate leaves for the merkle tree
        const leaves = [];
        const chainToLeafMap = new Map();
        
        for (const chainName of orderedChains) {
            const permit = this.permits[chainName];
            const leaf = await this.permit3Contracts[chainName].hashChainPermits(permit);
            leaves.push(leaf);
            chainToLeafMap.set(chainName, leaf);
        }
        
        // Build the merkle tree
        const merkleTree = MerkleTreeHelper.buildTree(leaves);
        const merkleRoot = MerkleTreeHelper.getRoot(merkleTree);
        
        // Create signature elements
        const salt = ethers.utils.randomBytes(32);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = timestamp + 3600; // 1 hour
        
        // Sign using any chain's domain (we'll use ethereum)
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
            verifyingContract: this.chains.ethereum.permit3Address
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
            owner: await wallet.getAddress(),
            salt,
            deadline,
            timestamp,
            merkleRoot
        };
        
        // Sign the message
        const signature = await wallet._signTypedData(domain, types, value);
        
        // Generate merkle proofs for each chain
        const proofs = {};
        
        for (const chainName of orderedChains) {
            const leaf = chainToLeafMap.get(chainName);
            proofs[chainName] = {
                permits: this.permits[chainName],
                proof: MerkleTreeHelper.getProof(merkleTree, leaf)
            };
        }
        
        return {
            owner: await wallet.getAddress(),
            salt,
            deadline,
            timestamp,
            signature,
            merkleRoot,
            chains: orderedChains,
            proofs
        };
    }
    
    // Execute permit on a specific chain
    async executeOnChain(chainName, permitData) {
        if (!this.chains[chainName]) {
            throw new Error(`Chain ${chainName} not configured`);
        }
        
        const { owner, salt, deadline, timestamp, signature, proofs } = permitData;
        const chainProof = proofs[chainName];
        
        if (!chainProof) {
            throw new Error(`No proof found for chain ${chainName}`);
        }
        
        // Get the contract for this chain
        const permit3 = this.permit3Contracts[chainName];
        
        // Execute the unbalanced permit
        const tx = await permit3.permit(
            owner,
            salt,
            deadline,
            timestamp,
            chainProof,
            signature
        );
        
        return tx;
    }
}

// Example usage
async function exampleCrossChainPermit() {
    // Initialize coordinator
    const coordinator = new CrossChainCoordinator();
    
    // Add permits for each chain
    coordinator.addChainPermit('ethereum', {
        chainId: 1,
        permits: [
            {
                token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
                amount: ethers.utils.parseUnits('100', 6),
                expiration: Math.floor(Date.now() / 1000) + 86400,
                spender: '0x1111111111111111111111111111111111111111'
            }
        ]
    });
    
    coordinator.addChainPermit('arbitrum', {
        chainId: 42161,
        permits: [
            {
                token: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', // USDC.e
                amount: ethers.utils.parseUnits('50', 6),
                expiration: Math.floor(Date.now() / 1000) + 86400,
                spender: '0x2222222222222222222222222222222222222222'
            }
        ]
    });
    
    coordinator.addChainPermit('optimism', {
        chainId: 10,
        permits: [
            {
                token: '0x7F5c764cBc14f9669B88837ca1490cCa17c31607', // USDC
                amount: ethers.utils.parseUnits('75', 6),
                expiration: Math.floor(Date.now() / 1000) + 86400,
                spender: '0x3333333333333333333333333333333333333333'
            }
        ]
    });
    
    // Generate cross-chain permit
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
    const crossChainPermit = await coordinator.generateCrossChainPermit(wallet);
    
    console.log('Cross-chain permit generated:', {
        root: crossChainPermit.merkleRoot,
        chains: crossChainPermit.chains,
        proofs: Object.keys(crossChainPermit.proofs)
    });
    
    // Execute on each chain
    for (const chainName of crossChainPermit.chains) {
        console.log(`Executing on ${chainName}...`);
        const tx = await coordinator.executeOnChain(chainName, crossChainPermit);
        console.log(`Transaction hash: ${tx.hash}`);
    }
}

module.exports = {
    CrossChainCoordinator,
    MerkleTreeHelper
};
```

### Smart Contract Integration

Here's how to interact with Permit3 from your smart contracts:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit3 } from "./interfaces/IPermit3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeFiProtocol {
    IPermit3 public immutable permit3;
    
    // Events
    event TokensReceived(address indexed from, address indexed token, uint256 amount);
    event ActionExecuted(address indexed user, string action);
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    // Use a single-chain permit to transfer tokens
    function executeWithPermit(
        address owner,
        IPermit3.ChainPermits calldata chainPermits,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp,
        bytes calldata signature
    ) external {
        // Use Permit3 to transfer tokens with the permit
        permit3.permit(owner, salt, deadline, timestamp, chainPermits.permits, signature);
        
        // Now we can transfer tokens from the owner
        for (uint i = 0; i < chainPermits.permits.length; i++) {
            IPermit3.AllowanceOrTransfer memory permit = chainPermits.permits[i];
            
            // Check if this is a transfer (mode = 0)
            if (permit.modeOrExpiration & 1 == 0) {
                // Extract transfer details
                uint160 amount = uint160(permit.modeOrExpiration >> 48);
                
                // Permit3 has already validated and will transfer the tokens
                emit TokensReceived(owner, permit.token, amount);
                
                // Execute your protocol logic here
                _executeProtocolAction(owner, permit.token, amount);
            }
        }
    }
    
    // Use a cross-chain permit
    function executeWithUnbalancedPermit(
        address owner,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp,
        IPermit3.UnbalancedPermitProof calldata proof,
        bytes calldata signature
    ) external {
        // Use Permit3 to process the unbalanced permit
        permit3.permit(owner, salt, deadline, timestamp, proof, signature);
        
        // Process the permits for this chain
        for (uint i = 0; i < proof.permits.permits.length; i++) {
            IPermit3.AllowanceOrTransfer memory permit = proof.permits.permits[i];
            
            // Check if this is a transfer (mode = 0)
            if (permit.modeOrExpiration & 1 == 0) {
                uint160 amount = uint160(permit.modeOrExpiration >> 48);
                emit TokensReceived(owner, permit.token, amount);
                _executeProtocolAction(owner, permit.token, amount);
            }
        }
    }
    
    // Internal protocol logic
    function _executeProtocolAction(address user, address token, uint256 amount) internal {
        // Your protocol logic here
        // For example: lending, swapping, staking, etc.
        emit ActionExecuted(user, "Protocol action completed");
    }
}
```

### Testing Your Integration

Here's a comprehensive test suite for your Permit3 integration:

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("Permit3 Integration Tests", function () {
    let permit3;
    let defiProtocol;
    let token;
    let owner;
    let spender;
    
    beforeEach(async function () {
        [owner, spender] = await ethers.getSigners();
        
        // Deploy contracts
        const Permit3 = await ethers.getContractFactory("Permit3");
        permit3 = await Permit3.deploy();
        
        const DeFiProtocol = await ethers.getContractFactory("DeFiProtocol");
        defiProtocol = await DeFiProtocol.deploy(permit3.address);
        
        const Token = await ethers.getContractFactory("MockERC20");
        token = await Token.deploy("Test Token", "TEST");
        
        // Setup: mint tokens and approve Permit3
        await token.mint(owner.address, ethers.utils.parseEther("1000"));
        await token.connect(owner).approve(permit3.address, ethers.constants.MaxUint256);
    });
    
    describe("Single Chain Permits", function () {
        it("Should create and execute a permit", async function () {
            const amount = ethers.utils.parseEther("100");
            const expiration = Math.floor(Date.now() / 1000) + 3600;
            
            // Create permit data
            const chainPermits = {
                chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility // Hardhat chainId
                permits: [{
                    modeOrExpiration: (BigInt(amount) << 48n) | BigInt(expiration),
                    token: token.address,
                    account: defiProtocol.address
                }]
            };
            
            // Generate signature
            const salt = ethers.utils.randomBytes(32);
            const timestamp = Math.floor(Date.now() / 1000);
            const deadline = timestamp + 3600;
            
            const domain = {
                name: "Permit3",
                version: "1",
                chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
                verifyingContract: permit3.address
            };
            
            const types = {
                Permit3: [
                    { name: "owner", type: "address" },
                    { name: "salt", type: "bytes32" },
                    { name: "deadline", type: "uint48" },
                    { name: "timestamp", type: "uint48" },
                    { name: "permitDataHash", type: "bytes32" }
                ]
            };
            
            const permitDataHash = await permit3.hashChainPermits(chainPermits);
            
            const value = {
                owner: owner.address,
                salt,
                deadline,
                timestamp,
                permitDataHash
            };
            
            const signature = await owner._signTypedData(domain, types, value);
            
            // Execute the permit
            await expect(
                defiProtocol.executeWithPermit(
                    owner.address,
                    chainPermits,
                    salt,
                    deadline,
                    timestamp,
                    signature
                )
            ).to.emit(defiProtocol, "TokensReceived")
             .withArgs(owner.address, token.address, amount);
        });
    });
    
    describe("Cross-Chain Permits", function () {
        it("Should create and execute an unbalanced permit", async function () {
            // Create permits for multiple chains
            const permits = [
                {
                    chainId: 1,
                    permits: [{
                        modeOrExpiration: (BigInt(ethers.utils.parseEther("50")) << 48n) | BigInt(Math.floor(Date.now() / 1000) + 3600),
                        token: token.address,
                        account: defiProtocol.address
                    }]
                },
                {
                    chainId: 42161,
                    permits: [{
                        modeOrExpiration: (BigInt(ethers.utils.parseEther("30")) << 48n) | BigInt(Math.floor(Date.now() / 1000) + 3600),
                        token: token.address,
                        account: spender.address
                    }]
                },
                {
                    chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility // Our test chain
                    permits: [{
                        modeOrExpiration: (BigInt(ethers.utils.parseEther("20")) << 48n) | BigInt(Math.floor(Date.now() / 1000) + 3600),
                        token: token.address,
                        account: defiProtocol.address
                    }]
                }
            ];
            
            // Generate merkle tree
            const leaves = [];
            for (const permit of permits) {
                const leaf = await permit3.hashChainPermits(permit);
                leaves.push(leaf);
            }
            
            const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
            const root = tree.getRoot();
            
            // Generate proof for our test chain (index 2)
            const ourChainLeaf = leaves[2];
            const proof = tree.getProof(ourChainLeaf).map(p => p.data);
            
            // Create signature
            const salt = ethers.utils.randomBytes(32);
            const timestamp = Math.floor(Date.now() / 1000);
            const deadline = timestamp + 3600;
            
            const domain = {
                name: "Permit3",
                version: "1",
                chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
                verifyingContract: permit3.address
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
                owner: owner.address,
                salt,
                deadline,
                timestamp,
                merkleRoot: root
            };
            
            const signature = await owner._signTypedData(domain, types, value);
            
            // Execute the unbalanced permit
            const proof = {
                permits: permits[2], // Our chain's permits
                proof: proof
            };
            
            await expect(
                defiProtocol.executeWithUnbalancedPermit(
                    owner.address,
                    salt,
                    deadline,
                    timestamp,
                    proof,
                    signature
                )
            ).to.emit(defiProtocol, "TokensReceived")
             .withArgs(owner.address, token.address, ethers.utils.parseEther("20"));
        });
    });
});
```

## Best Practices

### 1. Security Considerations

- Always verify signatures on-chain
- Implement proper deadline checks
- Use nonces to prevent replay attacks
- Validate token addresses and amounts

### 2. Gas Optimization

- Batch multiple operations in a single permit
- Use cross-chain permits only when necessary
- Cache merkle proofs when possible
- Optimize proof size by ordering chains efficiently

### 3. User Experience

- Provide clear feedback during signing
- Show gas estimates before execution
- Handle errors gracefully
- Implement retry mechanisms for failed transactions

### 4. Cross-Chain Coordination

- Use consistent chain ordering (by chainId)
- Implement proper error handling for each chain
- Monitor transaction status across chains
- Provide unified transaction history

## Troubleshooting

### Common Issues

1. **"Invalid signature" error**
   - Ensure the domain separator matches exactly
   - Check that all parameters are in the correct format
   - Verify the signer address matches the owner

2. **"Merkle proof verification failed"**
   - Ensure leaves are hashed correctly
   - Check that the proof order matches the tree construction
   - Verify the root calculation is consistent

3. **"Deadline exceeded" error**
   - Increase the deadline buffer
   - Check for time synchronization issues
   - Consider network delays

### Debugging Tips

```javascript
// Debug merkle tree construction
console.log("Leaves:", leaves.map(l => ethers.utils.hexlify(l)));
console.log("Root:", ethers.utils.hexlify(tree.getRoot()));
console.log("Proof:", proof.map(p => ethers.utils.hexlify(p)));

// Verify proof locally
const verified = tree.verify(proof, ourChainLeaf, root);
console.log("Proof valid:", verified);

// Debug signature
console.log("Domain:", domain);
console.log("Types:", types);
console.log("Value:", value);
console.log("Signature:", signature);
```

## Conclusion

This integration example demonstrates how to build a complete Permit3 implementation with:

- Frontend components for user interaction
- Backend services for cross-chain coordination
- Smart contract integration
- Comprehensive testing
- Best practices and troubleshooting

The Unbalanced Merkle tree methodology using standard merkle proofs with OpenZeppelin's MerkleProof makes the system easy to understand, implement, and maintain while providing powerful functionality for cross-chain operations.