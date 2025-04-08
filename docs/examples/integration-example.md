# Integration Example

This example demonstrates how to integrate Permit3 into a decentralized application, showing how different components interact to create a complete user experience.

## Full Stack Integration

We'll build a complete integration from frontend to smart contracts, using Permit3 to enable a seamless token approval and transfer flow.

### Frontend Components

Start by implementing a React component for permit creation:

```jsx
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
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

    // Create and sign permit
    async function createPermit() {
        setLoading(true);
        setError(null);
        setSuccess(false);
        
        try {
            // Get provider and signer
            const provider = await getProvider();
            const signer = provider.getSigner();
            const walletAddress = await signer.getAddress();
            const chainId = (await provider.getNetwork()).chainId;
            
            // Get selected token details
            const selectedToken = TOKENS.find(t => t.address === token);
            if (!selectedToken) throw new Error("Invalid token selection");
            
            // Parse amount with proper decimals
            const parsedAmount = ethers.utils.parseUnits(amount, selectedToken.decimals);
            
            // Calculate expiration timestamp
            const nowSeconds = Math.floor(Date.now() / 1000);
            const expirationTime = nowSeconds + (expiration * 60 * 60); // Convert hours to seconds
            
            // Create Permit3 contract instance
            const permit3 = new ethers.Contract(PERMIT3_ADDRESS, PERMIT3_ABI, signer);
            
            // Set up the permit data
            const chainPermits = {
                chainId,
                permits: [{
                    modeOrExpiration: expirationTime,
                    token: selectedToken.address,
                    account: spender,
                    amountDelta: parsedAmount
                }]
            };
            
            // Create signature elements
            const salt = ethers.utils.randomBytes(32);
            const deadline = nowSeconds + 3600; // 1 hour for transaction to be included
            const timestamp = nowSeconds;
            
            // Calculate hash for chain permits
            const permitsHash = await permit3.hashChainPermits(chainPermits);
            
            // Set up EIP-712 domain and types
            const domain = {
                name: "Permit3",
                version: "1",
                chainId,
                verifyingContract: PERMIT3_ADDRESS
            };
            
            const types = {
                SignedPermit3: [
                    { name: 'owner', type: 'address' },
                    { name: 'salt', type: 'bytes32' },
                    { name: 'deadline', type: 'uint256' },
                    { name: 'timestamp', type: 'uint48' },
                    { name: 'unhingedRoot', type: 'bytes32' }
                ]
            };
            
            // Create the value to sign
            const value = {
                owner: walletAddress,
                salt,
                deadline,
                timestamp,
                unhingedRoot: permitsHash
            };
            
            // Sign the message
            const signature = await signer._signTypedData(domain, types, value);
            
            // Execute the permit transaction
            const tx = await permit3.permit(
                walletAddress,
                salt,
                deadline,
                timestamp,
                chainPermits,
                signature
            );
            
            console.log("Transaction submitted:", tx.hash);
            await tx.wait();
            console.log("Transaction confirmed!");
            
            setSuccess(true);
        } catch (err) {
            console.error("Error creating permit:", err);
            setError(err.message || "An unknown error occurred");
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="token-approval-container">
            <h2>Create Token Approval</h2>
            
            <div className="form-group">
                <label>Token:</label>
                <select value={token} onChange={(e) => setToken(e.target.value)}>
                    <option value="">Select a token</option>
                    {TOKENS.map(t => (
                        <option key={t.address} value={t.address}>{t.symbol}</option>
                    ))}
                </select>
            </div>
            
            <div className="form-group">
                <label>Spender:</label>
                <select value={spender} onChange={(e) => setSpender(e.target.value)}>
                    <option value="">Select a spender</option>
                    {SPENDERS.map(s => (
                        <option key={s.address} value={s.address}>{s.name}</option>
                    ))}
                </select>
            </div>
            
            <div className="form-group">
                <label>Amount:</label>
                <input 
                    type="text" 
                    value={amount} 
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="Enter amount"
                />
            </div>
            
            <div className="form-group">
                <label>Expiration (hours):</label>
                <input 
                    type="number" 
                    value={expiration} 
                    onChange={(e) => setExpiration(parseInt(e.target.value))} 
                    min="1"
                    max="8760" // 1 year in hours
                />
            </div>
            
            <button 
                onClick={createPermit} 
                disabled={loading || !token || !spender || !amount}
                className="approve-button"
            >
                {loading ? "Processing..." : "Approve"}
            </button>
            
            {error && (
                <div className="error-message">
                    Error: {error}
                </div>
            )}
            
            {success && (
                <div className="success-message">
                    Approval created successfully!
                </div>
            )}
        </div>
    );
};

export default TokenApproval;
```

### Smart Contract Integration

Implement a contract that uses Permit3 to receive approvals and execute operations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@permit3/interfaces/IPermit3.sol";

contract Permit3Integration {
    IPermit3 public immutable permit3;
    
    event OperationExecuted(
        address indexed user,
        address indexed token,
        uint256 amount,
        bytes32 operationId
    );
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    /**
     * @notice Execute an operation after receiving approval via Permit3
     * @param token The token to transfer
     * @param amount The amount to transfer
     * @param permitOwner The owner of the permit
     * @param salt Random value for signature
     * @param deadline Timestamp after which signature is invalid
     * @param timestamp Operation timestamp
     * @param chainPermits Chain-specific permit data
     * @param signature The permit signature
     * @param operationId Unique identifier for this operation
     */
    function executeWithPermit(
        address token,
        uint256 amount,
        address permitOwner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.ChainPermits calldata chainPermits,
        bytes calldata signature,
        bytes32 operationId
    ) external {
        // Verify the chainId in the permits matches the current chain
        require(chainPermits.chainId == block.chainid, "Wrong chain ID");
        
        // Check that the permit is valid for this token and amount
        bool validPermit = false;
        for (uint i = 0; i < chainPermits.permits.length; i++) {
            IPermit3.AllowanceOrTransfer memory p = chainPermits.permits[i];
            if (p.token == token && p.account == address(this) && p.modeOrExpiration > 3) {
                // This is an increase mode permit for our contract
                validPermit = true;
                break;
            }
        }
        require(validPermit, "Invalid permit data");
        
        // Process the permit
        permit3.permit(
            permitOwner,
            salt,
            deadline,
            timestamp,
            chainPermits,
            signature
        );
        
        // Now transfer tokens from the user to this contract
        permit3.transferFrom(
            permitOwner,
            address(this),
            uint160(amount),
            token
        );
        
        // Execute the actual operation
        // This would be your business logic, like:
        // - Adding liquidity to a pool
        // - Staking tokens
        // - Executing a swap
        executeOperation(token, amount, permitOwner, operationId);
    }
    
    /**
     * @notice Witness-based execution for conditional operations
     */
    function executeWithWitness(
        address token,
        uint256 amount,
        address permitOwner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.ChainPermits calldata chainPermits,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature,
        bytes calldata witnessData,
        bytes32 operationId
    ) external {
        // Verify witness data matches expected format
        bytes32 expectedWitness = keccak256(witnessData);
        require(witness == expectedWitness, "Invalid witness data");
        
        // Process the permit with witness
        permit3.permitWitnessTransferFrom(
            permitOwner,
            salt,
            deadline,
            timestamp,
            chainPermits,
            witness,
            witnessTypeString,
            signature
        );
        
        // Execute operation with additional context from witness data
        // For example, this could be trade parameters, price limits, etc.
        executeWitnessOperation(token, amount, permitOwner, witnessData, operationId);
    }
    
    /**
     * @notice Cross-chain execution with UnhingedProof
     */
    function executeCrossChain(
        address token,
        uint256 amount,
        address permitOwner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.UnhingedPermitProof calldata unhingedPermitProof,
        bytes calldata signature,
        bytes32 operationId
    ) external {
        // Verify we're on the correct chain
        require(unhingedPermitProof.permits.chainId == block.chainid, "Wrong chain ID");
        
        // Process the cross-chain permit
        permit3.permit(
            permitOwner,
            salt,
            deadline,
            timestamp,
            unhingedPermitProof,
            signature
        );
        
        // Transfer tokens and execute operation
        permit3.transferFrom(
            permitOwner,
            address(this),
            uint160(amount),
            token
        );
        
        executeOperation(token, amount, permitOwner, operationId);
    }
    
    /**
     * @notice Backend for regular operations
     */
    function executeOperation(
        address token,
        uint256 amount,
        address user,
        bytes32 operationId
    ) internal {
        // Your core business logic goes here
        
        // For example, add liquidity to a pool, stake tokens, etc.
        // ...
        
        emit OperationExecuted(user, token, amount, operationId);
    }
    
    /**
     * @notice Backend for witness-based operations
     */
    function executeWitnessOperation(
        address token,
        uint256 amount,
        address user,
        bytes calldata witnessData,
        bytes32 operationId
    ) internal {
        // Parse witnessData for additional parameters
        // ...
        
        // Execute conditional operation based on witnessData
        // ...
        
        emit OperationExecuted(user, token, amount, operationId);
    }
}
```

### Backend Service Integration

Implement a backend service to monitor and validate Permit3 operations:

```javascript
const { ethers } = require('ethers');
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Setup provider and contract interfaces
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const permit3 = new ethers.Contract(
    process.env.PERMIT3_ADDRESS,
    PERMIT3_ABI,
    provider
);

// Track operation statuses
const operations = new Map();

// Endpoint to check permit status
app.get('/api/permit/status/:owner/:salt', async (req, res) => {
    try {
        const { owner, salt } = req.params;
        
        // Check if nonce is already used
        const isUsed = await permit3.isNonceUsed(owner, salt);
        
        res.json({ isUsed });
    } catch (error) {
        console.error('Error checking permit status:', error);
        res.status(500).json({ error: error.message });
    }
});

// Endpoint to validate a permit before execution
app.post('/api/permit/validate', async (req, res) => {
    try {
        const { owner, salt, deadline, timestamp, chainPermits, signature } = req.body;
        
        // Verify not expired
        if (deadline < Math.floor(Date.now() / 1000)) {
            return res.status(400).json({ valid: false, reason: 'Permit expired' });
        }
        
        // Verify nonce not used
        const isUsed = await permit3.isNonceUsed(owner, salt);
        if (isUsed) {
            return res.status(400).json({ valid: false, reason: 'Nonce already used' });
        }
        
        // Verify chain ID
        const networkChainId = (await provider.getNetwork()).chainId;
        if (chainPermits.chainId !== networkChainId) {
            return res.status(400).json({ valid: false, reason: 'Wrong chain ID' });
        }
        
        // Verify signature
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: networkChainId,
            verifyingContract: permit3.address
        };
        
        const types = {
            SignedPermit3: [
                { name: 'owner', type: 'address' },
                { name: 'salt', type: 'bytes32' },
                { name: 'deadline', type: 'uint256' },
                { name: 'timestamp', type: 'uint48' },
                { name: 'unhingedRoot', type: 'bytes32' }
            ]
        };
        
        const permitsHash = await permit3.hashChainPermits(chainPermits);
        
        const value = {
            owner,
            salt,
            deadline,
            timestamp,
            unhingedRoot: permitsHash
        };
        
        // Recover signer address
        const splitSignature = ethers.utils.splitSignature(signature);
        const digest = ethers.utils._TypedDataEncoder.hash(domain, types, value);
        const recoveredAddress = ethers.utils.recoverAddress(digest, splitSignature);
        
        const isValidSignature = (recoveredAddress.toLowerCase() === owner.toLowerCase());
        
        return res.json({
            valid: isValidSignature,
            reason: isValidSignature ? null : 'Invalid signature',
            recoveredSigner: recoveredAddress
        });
        
    } catch (error) {
        console.error('Error validating permit:', error);
        res.status(500).json({ valid: false, error: error.message });
    }
});

// Listen for Permit events
const permitFilter = permit3.filters.Permit();
const nonceUsedFilter = permit3.filters.NonceUsed();

permit3.on(permitFilter, (owner, token, spender, amount, expiration, timestamp, event) => {
    console.log(`New Permit detected:`);
    console.log(`  Owner: ${owner}`);
    console.log(`  Token: ${token}`);
    console.log(`  Spender: ${spender}`);
    console.log(`  Amount: ${ethers.utils.formatUnits(amount, 18)}`);
    console.log(`  Expiration: ${new Date(expiration * 1000).toLocaleString()}`);
    
    // Store in database or update application state
    // ...
});

permit3.on(nonceUsedFilter, (owner, salt, event) => {
    console.log(`Nonce Used:`);
    console.log(`  Owner: ${owner}`);
    console.log(`  Salt: ${salt}`);
    
    // Update operation status if this was a tracked operation
    const operationKey = `${owner.toLowerCase()}-${salt}`;
    if (operations.has(operationKey)) {
        operations.set(operationKey, { ...operations.get(operationKey), status: 'completed' });
    }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
```

### Cross-Chain Integration

Implement a cross-chain transaction coordinator:

```javascript
class CrossChainCoordinator {
    constructor(chains) {
        this.chains = chains;
        this.permits = {};
        this.providers = {};
        this.permit3Contracts = {};
        
        // Initialize providers and contracts for each chain
        Object.keys(chains).forEach(chainName => {
            const chain = chains[chainName];
            this.providers[chainName] = new ethers.providers.JsonRpcProvider(chain.rpcUrl);
            this.permit3Contracts[chainName] = new ethers.Contract(
                chain.permit3Address,
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
    
    // Generate the cross-chain permit with UnhingedMerkleTree
    async generateCrossChainPermit(wallet) {
        // Ensure we have all required data
        const chainNames = Object.keys(this.permits);
        if (chainNames.length === 0) {
            throw new Error("No chain permits configured");
        }
        
        // Order chains by chainId
        const orderedChains = chainNames.sort(
            (a, b) => this.chains[a].chainId - this.chains[b].chainId
        );
        
        // Generate chain hashes
        const hashes = {};
        await Promise.all(orderedChains.map(async chainName => {
            const permit = this.permits[chainName];
            hashes[chainName] = await this.permit3Contracts[chainName].hashChainPermits(permit);
        }));
        
        // Generate the unhinged root
        let unhingedRoot = hashes[orderedChains[0]];
        for (let i = 1; i < orderedChains.length; i++) {
            const chainName = orderedChains[i];
            unhingedRoot = this.hashLink(unhingedRoot, hashes[chainName]);
        }
        
        // Create signature elements
        const salt = ethers.utils.randomBytes(32);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = timestamp + 3600; // 1 hour
        
        // We can use any chain for signing, we'll use the first one
        const signingChain = orderedChains[0];
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: this.chains[signingChain].chainId,
            verifyingContract: this.chains[signingChain].permit3Address
        };
        
        const types = {
            SignedPermit3: [
                { name: 'owner', type: 'address' },
                { name: 'salt', type: 'bytes32' },
                { name: 'deadline', type: 'uint256' },
                { name: 'timestamp', type: 'uint48' },
                { name: 'unhingedRoot', type: 'bytes32' }
            ]
        };
        
        const value = {
            owner: await wallet.getAddress(),
            salt,
            deadline,
            timestamp,
            unhingedRoot
        };
        
        // Sign the message
        const signature = await wallet._signTypedData(domain, types, value);
        
        // Generate proofs for each chain
        const proofs = {};
        
        orderedChains.forEach((chainName, index) => {
            // For first chain
            if (index === 0) {
                const followingHashes = orderedChains.slice(1).map(c => hashes[c]);
                proofs[chainName] = {
                    permits: this.permits[chainName],
                    unhingedProof: this.createOptimizedProof(
                        ethers.constants.HashZero, // No preHash for first chain
                        [], // No subtree proof for the root itself
                        followingHashes
                    )
                };
            } 
            // For middle chains
            else if (index < orderedChains.length - 1) {
                // Calculate preHash from previous chains
                let preHash = hashes[orderedChains[0]];
                for (let i = 1; i < index; i++) {
                    preHash = this.hashLink(preHash, hashes[orderedChains[i]]);
                }
                
                // Following hashes are the remaining chains
                const followingHashes = orderedChains.slice(index + 1).map(c => hashes[c]);
                
                proofs[chainName] = {
                    permits: this.permits[chainName],
                    unhingedProof: this.createOptimizedProof(
                        preHash,
                        [], // No subtree proof for the root itself
                        followingHashes
                    )
                };
            }
            // For last chain
            else {
                // Calculate preHash from all previous chains
                let preHash = hashes[orderedChains[0]];
                for (let i = 1; i < index; i++) {
                    preHash = this.hashLink(preHash, hashes[orderedChains[i]]);
                }
                
                proofs[chainName] = {
                    permits: this.permits[chainName],
                    unhingedProof: this.createOptimizedProof(
                        preHash,
                        [], // No subtree proof for the root itself
                        [] // No following hashes for last chain
                    )
                };
            }
        });
        
        return {
            salt,
            deadline,
            timestamp,
            signature,
            proofs
        };
    }
    
    // Execute permits on each chain in parallel
    async executeAll(wallet, permitData) {
        const { salt, deadline, timestamp, signature, proofs } = permitData;
        const owner = await wallet.getAddress();
        
        const executionPromises = Object.keys(proofs).map(async chainName => {
            try {
                const chainWallet = new ethers.Wallet(wallet.privateKey, this.providers[chainName]);
                const permit3 = new ethers.Contract(
                    this.chains[chainName].permit3Address,
                    PERMIT3_ABI,
                    chainWallet
                );
                
                const tx = await permit3.permit(
                    owner,
                    salt,
                    deadline,
                    timestamp,
                    proofs[chainName],
                    signature
                );
                
                console.log(`Transaction submitted on ${chainName}: ${tx.hash}`);
                await tx.wait();
                console.log(`Transaction confirmed on ${chainName}: ${tx.hash}`);
                
                return { chain: chainName, success: true, hash: tx.hash };
            } catch (error) {
                console.error(`Error executing on ${chainName}:`, error);
                return { chain: chainName, success: false, error: error.message };
            }
        });
        
        return Promise.all(executionPromises);
    }
    
    // Utility function: hash link for UnhingedMerkleTree
    hashLink(a, b) {
        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes32", "bytes32"],
                [a, b]
            )
        );
    }
    
    // Utility function: create optimized proof
    createOptimizedProof(preHash, subtreeProof, followingHashes) {
        // Pack counts into a single bytes32
        const subtreeProofCount = subtreeProof.length;
        const followingHashesCount = followingHashes.length;
        const hasPreHash = preHash !== ethers.constants.HashZero;
        
        let countValue = ethers.BigNumber.from(0);
        countValue = countValue.or(ethers.BigNumber.from(subtreeProofCount).shl(136));
        countValue = countValue.or(ethers.BigNumber.from(followingHashesCount).shl(16));
        if (hasPreHash) countValue = countValue.or(1);
        
        // Combine nodes
        const nodes = [];
        if (hasPreHash) nodes.push(preHash);
        nodes.push(...subtreeProof, ...followingHashes);
        
        return {
            nodes,
            counts: ethers.utils.hexZeroPad(countValue.toHexString(), 32)
        };
    }
}

// Usage example
async function executeCrossChainOperation() {
    // Configure chains
    const chains = {
        ethereum: {
            chainId: 1,
            rpcUrl: "https://mainnet.infura.io/v3/YOUR_KEY",
            permit3Address: "0x000...1"
        },
        arbitrum: {
            chainId: 42161,
            rpcUrl: "https://arbitrum-mainnet.infura.io/v3/YOUR_KEY",
            permit3Address: "0x000...2"
        },
        optimism: {
            chainId: 10,
            rpcUrl: "https://optimism-mainnet.infura.io/v3/YOUR_KEY",
            permit3Address: "0x000...3"
        }
    };
    
    // Create coordinator
    const coordinator = new CrossChainCoordinator(chains);
    
    // Add permits for each chain
    coordinator.addChainPermit("ethereum", {
        chainId: 1,
        permits: [{
            modeOrExpiration: Math.floor(Date.now() / 1000) + 86400,
            token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC on Ethereum
            account: "0xDEF1...",
            amountDelta: ethers.utils.parseUnits("1000", 6)
        }]
    });
    
    coordinator.addChainPermit("arbitrum", {
        chainId: 42161,
        permits: [{
            modeOrExpiration: Math.floor(Date.now() / 1000) + 86400,
            token: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // USDC on Arbitrum
            account: "0xDEF2...",
            amountDelta: ethers.utils.parseUnits("500", 6)
        }]
    });
    
    coordinator.addChainPermit("optimism", {
        chainId: 10,
        permits: [{
            modeOrExpiration: 2, // Lock mode
            token: "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // USDC on Optimism
            account: ethers.constants.AddressZero,
            amountDelta: 0
        }]
    });
    
    // Connect wallet
    const wallet = new ethers.Wallet(PRIVATE_KEY);
    
    // Generate and execute the permit
    const permitData = await coordinator.generateCrossChainPermit(wallet);
    const results = await coordinator.executeAll(wallet, permitData);
    
    console.log("Cross-chain operation results:", results);
}
```

## Conclusion

This integration example demonstrates how to build a complete application using Permit3 with:

1. **Frontend Components**: React-based UI for creating permits
2. **Smart Contract Integration**: Contracts that utilize Permit3 for token approvals
3. **Backend Services**: Monitoring and validation of permits
4. **Cross-Chain Coordination**: Managing operations across multiple blockchains

By following this pattern, you can create seamless token approval experiences for users across multiple chains while maintaining security and flexibility.