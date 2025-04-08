# Security Example

This example demonstrates best practices for securing token permissions with Permit3's advanced security features.

## Emergency Lockdown System

One of Permit3's most powerful security features is the ability to quickly lock all token approvals in case of a security incident.

### Implementing a Multi-Chain Emergency Lockdown

```javascript
const { ethers } = require("ethers");

// Configure providers for multiple chains
const providers = {
    ethereum: new ethers.providers.JsonRpcProvider("https://mainnet.infura.io/v3/YOUR_KEY"),
    arbitrum: new ethers.providers.JsonRpcProvider("https://arbitrum-mainnet.infura.io/v3/YOUR_KEY"),
    optimism: new ethers.providers.JsonRpcProvider("https://optimism-mainnet.infura.io/v3/YOUR_KEY")
};

// Connect wallet to each provider
const wallets = {
    ethereum: new ethers.Wallet(PRIVATE_KEY, providers.ethereum),
    arbitrum: new ethers.Wallet(PRIVATE_KEY, providers.arbitrum),
    optimism: new ethers.Wallet(PRIVATE_KEY, providers.optimism)
};

// Permit3 addresses on each chain
const PERMIT3_ADDRESSES = {
    ethereum: "0x000...1", // Replace with actual address
    arbitrum: "0x000...2", // Replace with actual address
    optimism: "0x000...3"  // Replace with actual address
};

// Your tokens on each chain
const TOKENS = {
    ethereum: [
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
        "0x6B175474E89094C44Da98b954EedeAC495271d0F"  // DAI
    ],
    arbitrum: [
        "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // USDC
        "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"  // WETH
    ],
    optimism: [
        "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // USDC
        "0x4200000000000000000000000000000000000006"  // WETH
    ]
};

/**
 * Execute an emergency lockdown across multiple chains
 */
async function emergencyLockdown() {
    console.log("🚨 INITIATING EMERGENCY LOCKDOWN 🚨");
    
    // Generate common salt and timestamp for cross-chain correlation
    const salt = ethers.utils.randomBytes(32);
    const timestamp = Math.floor(Date.now() / 1000);
    const deadline = timestamp + 3600; // 1 hour deadline
    
    // Create permits for each chain
    const chainPermits = {};
    const chainIds = {
        ethereum: 1,
        arbitrum: 42161,
        optimism: 10
    };
    
    // Create lock permits for each chain
    Object.keys(TOKENS).forEach(chain => {
        chainPermits[chain] = {
            chainId: chainIds[chain],
            permits: TOKENS[chain].map(token => ({
                modeOrExpiration: 2, // Lock mode
                token,
                account: ethers.constants.AddressZero, // Not used for locking
                amountDelta: 0 // Not used for locking
            }))
        };
    });
    
    // Set up EIP-712 domain for signing
    const domain = {
        name: "Permit3",
        version: "1",
        chainId: 1, // Using Ethereum for signing
        verifyingContract: PERMIT3_ADDRESSES.ethereum
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
    
    // For multi-chain lockdown
    if (Object.keys(chainPermits).length > 1) {
        // Get permit3 contracts
        const permit3Contracts = {};
        Object.keys(PERMIT3_ADDRESSES).forEach(chain => {
            permit3Contracts[chain] = new ethers.Contract(
                PERMIT3_ADDRESSES[chain],
                ["function permit(address,bytes32,uint256,uint48,tuple(uint256,tuple(uint48,address,address,uint160)[]),bytes) external", 
                 "function hashChainPermits(tuple(uint256,tuple(uint48,address,address,uint160)[]) permits) external pure returns (bytes32)"],
                wallets[chain]
            );
        });
        
        // 1. Calculate hashes for each chain
        const hashes = {};
        await Promise.all(Object.keys(chainPermits).map(async chain => {
            hashes[chain] = await permit3Contracts[chain].hashChainPermits(chainPermits[chain]);
        }));
        
        // 2. Calculate unhinged root (order chains by chainId)
        const orderedChains = Object.keys(chainPermits).sort(
            (a, b) => chainIds[a] - chainIds[b]
        );
        
        // Create UnhingedMerkleTree for cross-chain operations
        const UnhingedMerkleTree = {
            hashLink: (a, b) => ethers.utils.keccak256(
                ethers.utils.defaultAbiCoder.encode(
                    ["bytes32", "bytes32"],
                    [a, b]
                )
            ),
            createOptimizedProof: (preHash, subtreeProof, followingHashes) => {
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
        };
        
        let unhingedRoot = hashes[orderedChains[0]];
        for (let i = 1; i < orderedChains.length; i++) {
            unhingedRoot = UnhingedMerkleTree.hashLink(unhingedRoot, hashes[orderedChains[i]]);
        }
        
        // 3. Sign the unhinged root
        const value = {
            owner: wallets.ethereum.address,
            salt,
            deadline,
            timestamp,
            unhingedRoot
        };
        
        const signature = await wallets.ethereum._signTypedData(domain, types, value);
        
        // 4. Create proofs for each chain
        const proofs = {};
        
        orderedChains.forEach((chain, index) => {
            // For first chain
            if (index === 0) {
                const followingHashes = orderedChains.slice(1).map(c => hashes[c]);
                proofs[chain] = {
                    permits: chainPermits[chain],
                    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
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
                    preHash = UnhingedMerkleTree.hashLink(preHash, hashes[orderedChains[i]]);
                }
                
                // Following hashes are the remaining chains
                const followingHashes = orderedChains.slice(index + 1).map(c => hashes[c]);
                
                proofs[chain] = {
                    permits: chainPermits[chain],
                    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
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
                    preHash = UnhingedMerkleTree.hashLink(preHash, hashes[orderedChains[i]]);
                }
                
                proofs[chain] = {
                    permits: chainPermits[chain],
                    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
                        preHash,
                        [], // No subtree proof for the root itself
                        [] // No following hashes for last chain
                    )
                };
            }
        });
        
        // 5. Execute lockdown on each chain in parallel with high gas price
        const lockPromises = orderedChains.map(async chain => {
            try {
                // Use higher gas price for emergency lockdown
                const gasPrice = await providers[chain].getGasPrice();
                const urgentGasPrice = gasPrice.mul(150).div(100); // 1.5x current gas price
                
                const tx = await permit3Contracts[chain].permit(
                    wallets[chain].address,
                    salt,
                    deadline,
                    timestamp,
                    proofs[chain],
                    signature,
                    { gasPrice: urgentGasPrice }
                );
                
                console.log(`🔒 Lockdown transaction submitted on ${chain}: ${tx.hash}`);
                await tx.wait();
                console.log(`✅ Lockdown confirmed on ${chain}: ${tx.hash}`);
                return { chain, success: true, tx: tx.hash };
            } catch (error) {
                console.error(`❌ Lockdown failed on ${chain}:`, error.message);
                return { chain, success: false, error: error.message };
            }
        });
        
        const results = await Promise.allSettled(lockPromises);
        
        // Log summary
        console.log("\n🔒 LOCKDOWN SUMMARY 🔒");
        results.forEach(result => {
            if (result.status === "fulfilled") {
                const { chain, success, tx, error } = result.value;
                if (success) {
                    console.log(`✅ ${chain.toUpperCase()}: Locked successfully (tx: ${tx})`); 
                } else {
                    console.log(`❌ ${chain.toUpperCase()}: Failed - ${error}`);
                }
            } else {
                console.log(`❌ Chain execution failed: ${result.reason}`);
            }
        });
        
        return results;
    } 
    // For single-chain lockdown
    else {
        const chain = Object.keys(chainPermits)[0];
        const permit3 = new ethers.Contract(
            PERMIT3_ADDRESSES[chain],
            ["function permit(address,bytes32,uint256,uint48,tuple(uint256,tuple(uint48,address,address,uint160)[]),bytes) external",
             "function hashChainPermits(tuple(uint256,tuple(uint48,address,address,uint160)[]) permits) external pure returns (bytes32)"],
            wallets[chain]
        );
        
        // Calculate hash and sign
        const permitsHash = await permit3.hashChainPermits(chainPermits[chain]);
        
        const value = {
            owner: wallets[chain].address,
            salt,
            deadline,
            timestamp,
            unhingedRoot: permitsHash
        };
        
        const signature = await wallets[chain]._signTypedData(domain, types, value);
        
        // Get current gas price and increase for urgency
        const gasPrice = await providers[chain].getGasPrice();
        const urgentGasPrice = gasPrice.mul(150).div(100); // 1.5x current gas price
        
        try {
            const tx = await permit3.permit(
                wallets[chain].address,
                salt,
                deadline,
                timestamp,
                chainPermits[chain],
                signature,
                { gasPrice: urgentGasPrice }
            );
            
            console.log(`🔒 Lockdown transaction submitted on ${chain}: ${tx.hash}`);
            await tx.wait();
            console.log(`✅ Lockdown confirmed on ${chain}: ${tx.hash}`);
            return { chain, success: true, tx: tx.hash };
        } catch (error) {
            console.error(`❌ Lockdown failed on ${chain}:`, error.message);
            return { chain, success: false, error: error.message };
        }
    }
}

// Usage
emergencyLockdown().catch(console.error);
```

## Nonce Security

Secure nonce management is crucial for preventing replay attacks.

### Invalidating Multiple Nonces

```javascript
async function invalidateNonces(nonceArray) {
    const permit3 = new ethers.Contract(
        PERMIT3_ADDRESS,
        ["function invalidateNonces(bytes32[] calldata salts) external",
         "function isNonceUsed(address owner, bytes32 salt) external view returns (bool)"],
        wallet
    );
    
    // Filter out already used nonces
    const unusedNonces = [];
    for (const nonce of nonceArray) {
        const isUsed = await permit3.isNonceUsed(wallet.address, nonce);
        if (!isUsed) {
            unusedNonces.push(nonce);
        }
    }
    
    if (unusedNonces.length === 0) {
        console.log("No unused nonces to invalidate");
        return;
    }
    
    // Invalidate all unused nonces in a single transaction
    const tx = await permit3.invalidateNonces(unusedNonces);
    console.log(`Invalidating ${unusedNonces.length} nonces, tx hash: ${tx.hash}`);
    await tx.wait();
    console.log(`Successfully invalidated ${unusedNonces.length} nonces`);
}
```

## Time-Bound Allowances

Time-bound allowances are a key security feature of Permit3, limiting the window of vulnerability.

```javascript
// Set up an allowance with a short expiration
async function setShortLivedAllowance(token, spender, amount, hours) {
    const nowSeconds = Math.floor(Date.now() / 1000);
    const expiration = nowSeconds + (hours * 60 * 60); // Convert hours to seconds
    
    const chainPermits = {
        chainId: await getChainId(),
        permits: [{
            modeOrExpiration: expiration,
            token,
            account: spender,
            amountDelta: amount
        }]
    };
    
    // Generate salt, deadline, sign, and send
    // ... standard permit signing code ...
    
    console.log(`Set allowance of ${ethers.utils.formatUnits(amount, decimals)} tokens`);
    console.log(`Expires in ${hours} hours at ${new Date(expiration * 1000).toLocaleString()}`);
}
```

## Securing Witness Data

When using witness functionality, it's crucial to validate the witness data thoroughly.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract SecureTradeExecutor {
    IPermit3 public immutable permit3;
    
    // Security settings
    uint256 public maxPriceImpact;      // Maximum price impact in basis points (100 = 1%)
    uint256 public maxTradeSize;        // Maximum trade size
    uint256 public maxWitnessAge;       // Maximum age of witness data
    
    constructor(
        address _permit3,
        uint256 _maxPriceImpact,
        uint256 _maxTradeSize,
        uint256 _maxWitnessAge
    ) {
        permit3 = IPermit3(_permit3);
        maxPriceImpact = _maxPriceImpact;
        maxTradeSize = _maxTradeSize;
        maxWitnessAge = _maxWitnessAge;
    }
    
    struct TradeData {
        uint256 orderId;
        uint256 price;
        uint256 timestamp;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
    }
    
    function executeSecureTrade(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.ChainPermits calldata chainPermits,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature,
        TradeData calldata tradeData
    ) external {
        // 1. Verify witness is correctly constructed
        bytes32 expectedWitness = keccak256(abi.encode(
            tradeData.orderId,
            tradeData.price,
            tradeData.timestamp,
            tradeData.tokenIn,
            tradeData.tokenOut,
            tradeData.amountIn,
            tradeData.minAmountOut,
            tradeData.recipient
        ));
        
        require(witness == expectedWitness, "Invalid witness");
        
        // 2. Security checks
        
        // Check witness age
        require(
            block.timestamp - tradeData.timestamp <= maxWitnessAge,
            "Witness data too old"
        );
        
        // Check trade size
        require(tradeData.amountIn <= maxTradeSize, "Trade size exceeds maximum");
        
        // Check recipient
        require(
            tradeData.recipient == owner || tradeData.recipient == address(this),
            "Unauthorized recipient"
        );
        
        // 3. Execute permit with witness
        permit3.permitWitnessTransferFrom(
            owner,
            salt,
            deadline,
            timestamp,
            chainPermits,
            witness,
            witnessTypeString,
            signature
        );
        
        // 4. Execute the actual trade logic
        // ...
        
        // 5. Verify minimum output
        uint256 actualOutput = /* actual output amount */;
        require(actualOutput >= tradeData.minAmountOut, "Insufficient output amount");
        
        // 6. Calculate price impact
        uint256 expectedOutput = (tradeData.amountIn * tradeData.price) / 1e18;
        uint256 priceImpact = ((expectedOutput - actualOutput) * 10000) / expectedOutput;
        
        require(priceImpact <= maxPriceImpact, "Price impact too high");
        
        // 7. Transfer output tokens to recipient
        // ...
        
        emit TradeExecuted(
            owner,
            tradeData.orderId,
            tradeData.tokenIn,
            tradeData.tokenOut,
            tradeData.amountIn,
            actualOutput,
            priceImpact
        );
    }
    
    event TradeExecuted(
        address indexed owner,
        uint256 orderId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 priceImpact
    );
}
```

## Monitoring Tools

Implementing monitoring tools can help detect and respond to security issues quickly.

```javascript
// Monitor for suspicious permit activity
async function monitorPermits() {
    // Set up ethers provider
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    
    // Create interface for Permit3 events
    const permit3Interface = new ethers.utils.Interface([
        "event Permit(address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration, uint48 timestamp)",
        "event NonceInvalidation(address indexed owner, bytes32 indexed salt)",
        "event NonceUsed(address indexed owner, bytes32 indexed salt)"
    ]);
    
    // Addresses to monitor
    const MONITORED_ADDRESSES = [
        "0x...1", "0x...2", "0x...3"
    ];
    
    // Create a filter for Permit events
    const permitFilter = {
        address: PERMIT3_ADDRESS,
        topics: [
            permit3Interface.getEventTopic("Permit"),
            MONITORED_ADDRESSES.map(addr => ethers.utils.hexZeroPad(addr, 32))
        ]
    };
    
    // Create a filter for NonceInvalidation events
    const invalidationFilter = {
        address: PERMIT3_ADDRESS,
        topics: [
            permit3Interface.getEventTopic("NonceInvalidation"),
            MONITORED_ADDRESSES.map(addr => ethers.utils.hexZeroPad(addr, 32))
        ]
    };
    
    console.log("Starting permit monitoring...");
    
    // Listen for Permit events
    provider.on(permitFilter, (log) => {
        const parsedLog = permit3Interface.parseLog(log);
        const { owner, token, spender, amount, expiration, timestamp } = parsedLog.args;
        
        console.log(`🔔 New Permit detected:`);
        console.log(`  Owner: ${owner}`);
        console.log(`  Token: ${token}`);
        console.log(`  Spender: ${spender}`);
        console.log(`  Amount: ${ethers.utils.formatUnits(amount, 18)}`);
        console.log(`  Expiration: ${new Date(expiration * 1000).toLocaleString()}`);
        
        // Check for suspicious activity
        const isUnlimitedApproval = amount.eq(ethers.constants.MaxUint256);
        const isSuspiciousSpender = !KNOWN_SPENDERS.includes(spender.toLowerCase());
        const longExpiration = expiration > Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // > 30 days
        
        if (isUnlimitedApproval && isSuspiciousSpender) {
            console.log(`⚠️ ALERT: Unlimited approval to unknown spender!`);
            sendAlert(`Owner ${owner} granted unlimited approval to unknown spender ${spender}`);
        }
        
        if (longExpiration && isSuspiciousSpender) {
            console.log(`⚠️ ALERT: Long expiration approval to unknown spender!`);
            sendAlert(`Owner ${owner} granted approval with long expiration to unknown spender ${spender}`);
        }
    });
    
    // Listen for NonceInvalidation events
    provider.on(invalidationFilter, (log) => {
        const parsedLog = permit3Interface.parseLog(log);
        const { owner, salt } = parsedLog.args;
        
        console.log(`🔔 Nonce Invalidation detected:`);
        console.log(`  Owner: ${owner}`);
        console.log(`  Salt: ${salt}`);
        
        // Multiple invalidations in short time could indicate security issue
        // Track and alert if needed
    });
}

function sendAlert(message) {
    // Send email, Slack notification, or other alert mechanism
    console.log(`🚨 SECURITY ALERT: ${message}`);
    // Your alert implementation here
}
```

## Conclusion

This example demonstrates several security best practices for Permit3:

1. **Emergency Lockdown** - Quick response to security incidents across chains
2. **Nonce Management** - Preventing replay attacks by invalidating nonces
3. **Time-Bound Allowances** - Limiting the window of vulnerability
4. **Secure Witness Validation** - Thorough validation of witness data
5. **Monitoring** - Proactive detection of suspicious activity

By implementing these security patterns, you can significantly reduce the risk associated with token approvals and protect user assets during security incidents.