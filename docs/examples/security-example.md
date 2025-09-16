# Security Example

This example demonstrates best practices for securing token permissions with Permit3's advanced security features.

## Emergency Lockdown System

One of Permit3's most powerful security features is the ability to quickly lock all token approvals in case of a security incident.

### Implementing a Multi-Chain Emergency Lockdown

```javascript
const { ethers } = require("ethers");
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

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

// Spenders you've given permissions to
const SPENDERS = [
    "0x1111111111111111111111111111111111111111", // DEX A
    "0x2222222222222222222222222222222222222222", // Lending Protocol B
    "0x3333333333333333333333333333333333333333"  // Yield Aggregator C
];

async function emergencyLockdownAllChains() {
    console.log("🚨 INITIATING EMERGENCY LOCKDOWN 🚨");
    
    try {
        // 1. Create lockdown permits for each chain
        const chainPermits = {};
        const hashes = {};
        
        for (const [chain, tokens] of Object.entries(TOKENS)) {
            const permits = [];
            
            // Create a lockdown permit for each token/spender combination
            for (const token of tokens) {
                for (const spender of SPENDERS) {
                    permits.push({
                        modeOrExpiration: 0x1, // Mode 1 = lockdown (set allowance to 0)
                        token: token,
                        account: spender
                    });
                }
            }
            
            // Create chain permit structure
            chainPermits[chain] = {
                chainId: await providers[chain].getNetwork().then(n => n.chainId),
                permits: permits
            };
            
            // Calculate hash for this chain
            const permit3 = new ethers.Contract(
                PERMIT3_ADDRESSES[chain],
                PERMIT3_ABI,
                providers[chain]
            );
            
            hashes[chain] = await permit3.hashChainPermits(chainPermits[chain]);
        }
        
        // 2. Build merkle tree for all chains
        const orderedChains = Object.keys(chainPermits).sort();
        const leaves = orderedChains.map(chain => hashes[chain]);
        
        // Create merkle tree with ordered hashing
        const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        const merkleRoot = '0x' + merkleTree.getRoot().toString('hex');
        
        // 3. Sign the unbalanced root
        const salt = ethers.utils.randomBytes(32);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = timestamp + 300; // 5 minutes - quick action needed!
        
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: 1, // Always use mainnet for signing
            verifyingContract: PERMIT3_ADDRESSES.ethereum
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
            owner: wallets.ethereum.address,
            salt,
            deadline,
            timestamp,
            merkleRoot
        };
        
        const signature = await wallets.ethereum._signTypedData(domain, types, value);
        
        // 4. Create merkle proofs for each chain
        const proofs = {};
        
        orderedChains.forEach((chain, index) => {
            const leaf = hashes[chain];
            const proof = merkleTree.getProof(leaf);
            
            proofs[chain] = {
                permits: chainPermits[chain],
                proof: proof.map(p => '0x' + p.data.toString('hex'))
            };
        });
        
        // 5. Execute lockdown on all chains in parallel
        const lockdownPromises = orderedChains.map(async (chain) => {
            const permit3 = new ethers.Contract(
                PERMIT3_ADDRESSES[chain],
                PERMIT3_ABI,
                wallets[chain]
            );
            
            console.log(`🔒 Locking down ${chain}...`);
            
            const tx = await permit3.permit(
                wallets[chain].address,
                salt,
                deadline,
                timestamp,
                proofs[chain],
                signature
            );
            
            await tx.wait();
            console.log(`✅ ${chain} locked down - tx: ${tx.hash}`);
            
            return { chain, tx: tx.hash };
        });
        
        const results = await Promise.all(lockdownPromises);
        
        console.log("🛡️ EMERGENCY LOCKDOWN COMPLETE 🛡️");
        console.log("All permissions have been revoked across all chains");
        console.log("Results:", results);
        
        return results;
        
    } catch (error) {
        console.error("❌ LOCKDOWN FAILED:", error);
        throw error;
    }
}

// Execute emergency lockdown when needed
// emergencyLockdownAllChains();
```

## Time-Based Security Controls

Implement automatic expiration for high-risk operations:

```javascript
class SecurePermitManager {
    constructor(permit3Address, provider) {
        this.permit3 = new ethers.Contract(permit3Address, PERMIT3_ABI, provider);
        this.provider = provider;
    }
    
    // Create a permit with strict time controls
    async createTimeBoundPermit(params) {
        const {
            token,
            spender,
            amount,
            maxDurationHours = 24, // Default 24 hour max
            requireRecentTimestamp = true,
            signer
        } = params;
        
        const now = Math.floor(Date.now() / 1000);
        
        // Security check: ensure timestamp is recent
        if (requireRecentTimestamp) {
            const blockTimestamp = await this.provider.getBlock('latest')
                .then(b => b.timestamp);
            
            if (Math.abs(now - blockTimestamp) > 300) { // 5 minute tolerance
                throw new Error("Clock skew detected - potential security risk");
            }
        }
        
        // Calculate secure expiration
        const expiration = now + (maxDurationHours * 3600);
        
        // Create permit data
        const permitData = {
            modeOrExpiration: (BigInt(amount) << 48n) | BigInt(expiration),
            token: token,
            account: spender
        };
        
        const chainPermits = {
            chainId: await this.provider.getNetwork().then(n => n.chainId),
            permits: [permitData]
        };
        
        // Generate secure salt
        const salt = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "uint256", "uint256"],
                [token, spender, amount, now]
            )
        );
        
        // Sign with short deadline
        const deadline = now + 600; // 10 minute signing window
        const timestamp = now;
        
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
            verifyingContract: this.permit3.address
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
        
        const permitDataHash = await this.permit3.hashChainPermits(chainPermits);
        
        const value = {
            owner: await signer.getAddress(),
            salt,
            deadline,
            timestamp,
            permitDataHash
        };
        
        const signature = await signer._signTypedData(domain, types, value);
        
        return {
            chainPermits,
            salt,
            deadline,
            timestamp,
            signature,
            metadata: {
                expiresAt: new Date(expiration * 1000),
                createdAt: new Date(now * 1000),
                maxDuration: maxDurationHours
            }
        };
    }
    
    // Monitor and alert on suspicious activity
    async monitorPermitUsage(owner, options = {}) {
        const {
            checkInterval = 60000, // Check every minute
            maxPermitsPerHour = 10,
            maxAmountPerDay = ethers.utils.parseEther("10000"),
            alertCallback
        } = options;
        
        const permitHistory = [];
        
        const checkSuspiciousActivity = async () => {
            // Get recent events
            const filter = this.permit3.filters.Permit(owner);
            const events = await this.permit3.queryFilter(filter, -1000); // Last 1000 blocks
            
            const now = Date.now();
            const oneHourAgo = now - 3600000;
            const oneDayAgo = now - 86400000;
            
            // Count permits in last hour
            const recentPermits = events.filter(e => {
                const timestamp = e.args.timestamp * 1000;
                return timestamp > oneHourAgo;
            });
            
            // Calculate total amount in last day
            let dailyAmount = ethers.BigNumber.from(0);
            events.forEach(event => {
                const timestamp = event.args.timestamp * 1000;
                if (timestamp > oneDayAgo) {
                    // Extract amount from modeOrExpiration
                    const amount = event.args.modeOrExpiration.shr(48);
                    dailyAmount = dailyAmount.add(amount);
                }
            });
            
            // Check for suspicious patterns
            const alerts = [];
            
            if (recentPermits.length > maxPermitsPerHour) {
                alerts.push({
                    type: "RATE_LIMIT_EXCEEDED",
                    message: `${recentPermits.length} permits created in last hour`,
                    severity: "HIGH"
                });
            }
            
            if (dailyAmount.gt(maxAmountPerDay)) {
                alerts.push({
                    type: "AMOUNT_LIMIT_EXCEEDED",
                    message: `Daily amount ${ethers.utils.formatEther(dailyAmount)} exceeds limit`,
                    severity: "CRITICAL"
                });
            }
            
            // Check for rapid sequential permits
            const rapidPermits = [];
            for (let i = 1; i < recentPermits.length; i++) {
                const timeDiff = recentPermits[i].args.timestamp - recentPermits[i-1].args.timestamp;
                if (timeDiff < 60) { // Less than 1 minute apart
                    rapidPermits.push(recentPermits[i]);
                }
            }
            
            if (rapidPermits.length > 2) {
                alerts.push({
                    type: "RAPID_PERMIT_CREATION",
                    message: `${rapidPermits.length} permits created rapidly`,
                    severity: "MEDIUM"
                });
            }
            
            // Trigger alerts
            if (alerts.length > 0 && alertCallback) {
                await alertCallback(alerts);
            }
            
            return alerts;
        };
        
        // Start monitoring
        const intervalId = setInterval(checkSuspiciousActivity, checkInterval);
        
        // Return monitor control object
        return {
            stop: () => clearInterval(intervalId),
            checkNow: checkSuspiciousActivity,
            getHistory: () => permitHistory
        };
    }
}

// Usage example
async function setupSecurePermits() {
    const manager = new SecurePermitManager(PERMIT3_ADDRESS, provider);
    
    // Create a time-bound permit
    const permit = await manager.createTimeBoundPermit({
        token: USDC_ADDRESS,
        spender: DEX_ADDRESS,
        amount: ethers.utils.parseUnits("1000", 6),
        maxDurationHours: 2, // Only valid for 2 hours
        signer: wallet
    });
    
    console.log("Permit created:", permit.metadata);
    
    // Set up monitoring
    const monitor = await manager.monitorPermitUsage(wallet.address, {
        maxPermitsPerHour: 5,
        maxAmountPerDay: ethers.utils.parseUnits("5000", 6),
        alertCallback: async (alerts) => {
            console.error("🚨 SECURITY ALERTS:", alerts);
            
            // Take action based on severity
            const criticalAlert = alerts.find(a => a.severity === "CRITICAL");
            if (criticalAlert) {
                console.log("Initiating emergency lockdown...");
                await emergencyLockdownAllChains();
            }
        }
    });
    
    return { permit, monitor };
}
```

## Secure Multi-Signature Patterns

For high-value operations, implement multi-signature requirements:

```javascript
class MultiSigPermitManager {
    constructor(permit3Address, provider) {
        this.permit3 = new ethers.Contract(permit3Address, PERMIT3_ABI, provider);
        this.provider = provider;
        this.pendingOperations = new Map();
    }
    
    // Create a multi-sig permit operation
    async proposeMultiSigPermit(params) {
        const {
            token,
            spender,
            amount,
            requiredSignatures = 2,
            signers = [],
            expirationHours = 24
        } = params;
        
        if (signers.length < requiredSignatures) {
            throw new Error("Not enough signers for required signatures");
        }
        
        const operationId = ethers.utils.id(
            `${token}-${spender}-${amount}-${Date.now()}`
        );
        
        const now = Math.floor(Date.now() / 1000);
        const expiration = now + (expirationHours * 3600);
        
        // Create the permit data
        const permitData = {
            modeOrExpiration: (BigInt(amount) << 48n) | BigInt(expiration),
            token: token,
            account: spender
        };
        
        const chainPermits = {
            chainId: await this.provider.getNetwork().then(n => n.chainId),
            permits: [permitData]
        };
        
        // Create operation record
        const operation = {
            id: operationId,
            chainPermits,
            requiredSignatures,
            signers,
            signatures: new Map(),
            status: "pending",
            createdAt: now,
            expiresAt: now + 86400 // 24 hour window to collect signatures
        };
        
        this.pendingOperations.set(operationId, operation);
        
        return {
            operationId,
            operation,
            signatureRequest: await this.createSignatureRequest(operation)
        };
    }
    
    // Create signature request for a signer
    async createSignatureRequest(operation) {
        const salt = ethers.utils.id(operation.id);
        const timestamp = Math.floor(Date.now() / 1000);
        const deadline = operation.expiresAt;
        
        const permitDataHash = await this.permit3.hashChainPermits(operation.chainPermits);
        
        const domain = {
            name: "Permit3",
            version: "1",
            chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
            verifyingContract: this.permit3.address
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
        
        return {
            domain,
            types,
            value: {
                owner: operation.signers[0], // Primary owner
                salt,
                deadline,
                timestamp,
                permitDataHash
            }
        };
    }
    
    // Collect signature from a signer
    async addSignature(operationId, signer, signature) {
        const operation = this.pendingOperations.get(operationId);
        if (!operation) {
            throw new Error("Operation not found");
        }
        
        if (!operation.signers.includes(signer)) {
            throw new Error("Signer not authorized for this operation");
        }
        
        if (operation.signatures.has(signer)) {
            throw new Error("Signature already provided");
        }
        
        // Verify signature is valid
        const signatureRequest = await this.createSignatureRequest(operation);
        const recoveredAddress = ethers.utils.verifyTypedData(
            signatureRequest.domain,
            signatureRequest.types,
            signatureRequest.value,
            signature
        );
        
        if (recoveredAddress.toLowerCase() !== signer.toLowerCase()) {
            throw new Error("Invalid signature");
        }
        
        operation.signatures.set(signer, signature);
        
        // Check if we have enough signatures
        if (operation.signatures.size >= operation.requiredSignatures) {
            operation.status = "ready";
            return { ready: true, operation };
        }
        
        return { 
            ready: false, 
            collected: operation.signatures.size,
            required: operation.requiredSignatures
        };
    }
    
    // Execute the multi-sig permit
    async executeMultiSigPermit(operationId) {
        const operation = this.pendingOperations.get(operationId);
        if (!operation) {
            throw new Error("Operation not found");
        }
        
        if (operation.status !== "ready") {
            throw new Error("Operation not ready - insufficient signatures");
        }
        
        if (Math.floor(Date.now() / 1000) > operation.expiresAt) {
            throw new Error("Operation expired");
        }
        
        // Use the first signature (primary owner)
        const primaryOwner = operation.signers[0];
        const signature = operation.signatures.get(primaryOwner);
        
        const signatureRequest = await this.createSignatureRequest(operation);
        
        // Execute the permit
        const tx = await this.permit3.permit(
            primaryOwner,
            operation.chainPermits,
            signatureRequest.value.salt,
            signatureRequest.value.deadline,
            signatureRequest.value.timestamp,
            signature
        );
        
        await tx.wait();
        
        operation.status = "executed";
        operation.txHash = tx.hash;
        
        return {
            success: true,
            txHash: tx.hash,
            operation
        };
    }
}

// Usage example
async function setupMultiSigPermit() {
    const manager = new MultiSigPermitManager(PERMIT3_ADDRESS, provider);
    
    // Propose a high-value operation requiring multiple signatures
    const proposal = await manager.proposeMultiSigPermit({
        token: WETH_ADDRESS,
        spender: VAULT_ADDRESS,
        amount: ethers.utils.parseEther("100"), // 100 ETH - high value!
        requiredSignatures: 3,
        signers: [wallet1.address, wallet2.address, wallet3.address],
        expirationHours: 48
    });
    
    console.log("Multi-sig operation proposed:", proposal.operationId);
    
    // Each signer signs the operation
    for (const wallet of [wallet1, wallet2, wallet3]) {
        const signature = await wallet._signTypedData(
            proposal.signatureRequest.domain,
            proposal.signatureRequest.types,
            proposal.signatureRequest.value
        );
        
        const result = await manager.addSignature(
            proposal.operationId,
            wallet.address,
            signature
        );
        
        console.log(`Signature ${result.collected}/${result.required} collected`);
        
        if (result.ready) {
            console.log("Ready to execute!");
            break;
        }
    }
    
    // Execute the multi-sig permit
    const execution = await manager.executeMultiSigPermit(proposal.operationId);
    console.log("Multi-sig permit executed:", execution.txHash);
}
```

## Best Security Practices

### 1. Regular Security Audits

```javascript
async function auditPermissions(owner, permit3) {
    const audit = {
        timestamp: new Date(),
        owner,
        activePermissions: [],
        risks: [],
        recommendations: []
    };
    
    // Get all permit events for this owner
    const filter = permit3.filters.Permit(owner);
    const events = await permit3.queryFilter(filter);
    
    // Analyze each permission
    for (const event of events) {
        const { token, account, modeOrExpiration } = event.args;
        const mode = modeOrExpiration & 1n;
        
        if (mode === 0n) { // TransferERC20 mode
            const amount = modeOrExpiration >> 48n;
            const expiration = Number(modeOrExpiration >> 208n);
            const now = Math.floor(Date.now() / 1000);
            
            if (expiration > now) {
                audit.activePermissions.push({
                    token,
                    spender: account,
                    amount: amount.toString(),
                    expiresAt: new Date(expiration * 1000),
                    remainingTime: expiration - now
                });
                
                // Check for risks
                if (amount > ethers.utils.parseEther("1000")) {
                    audit.risks.push({
                        type: "HIGH_VALUE_PERMISSION",
                        token,
                        spender: account,
                        amount: ethers.utils.formatEther(amount)
                    });
                }
                
                if (expiration - now > 86400 * 30) { // More than 30 days
                    audit.risks.push({
                        type: "LONG_DURATION_PERMISSION",
                        token,
                        spender: account,
                        expiresIn: `${Math.floor((expiration - now) / 86400)} days`
                    });
                }
            }
        }
    }
    
    // Generate recommendations
    if (audit.activePermissions.length > 10) {
        audit.recommendations.push(
            "Consider revoking unused permissions to reduce attack surface"
        );
    }
    
    if (audit.risks.filter(r => r.type === "HIGH_VALUE_PERMISSION").length > 0) {
        audit.recommendations.push(
            "High-value permissions detected - consider using time-limited permits"
        );
    }
    
    return audit;
}
```

### 2. Secure Key Management

```javascript
// Never expose private keys directly
// Use environment variables and secure key management services

class SecureWalletManager {
    constructor() {
        this.wallets = new Map();
    }
    
    // Load wallet from encrypted keystore
    async loadFromKeystore(keystorePath, password) {
        const keystore = await fs.readFile(keystorePath, 'utf8');
        const wallet = await ethers.Wallet.fromEncryptedJson(keystore, password);
        
        this.wallets.set(wallet.address, wallet);
        return wallet.address;
    }
    
    // Use hardware wallet for high-value operations
    async connectHardwareWallet(type = 'ledger') {
        // Implementation depends on hardware wallet SDK
        // Example with Ledger:
        const { LedgerSigner } = require("@ethersproject/hardware-wallets");
        
        const signer = new LedgerSigner(provider, "m/44'/60'/0'/0/0");
        const address = await signer.getAddress();
        
        this.wallets.set(address, signer);
        return address;
    }
    
    // Get signer with security checks
    async getSigner(address, requireHardware = false) {
        const signer = this.wallets.get(address);
        
        if (!signer) {
            throw new Error("Signer not found");
        }
        
        if (requireHardware && !(signer instanceof LedgerSigner)) {
            throw new Error("Hardware wallet required for this operation");
        }
        
        return signer;
    }
}
```

## Security Monitoring Dashboard

```javascript
// Real-time security monitoring
class SecurityMonitor {
    constructor(permit3Addresses) {
        this.permit3Addresses = permit3Addresses;
        this.alerts = [];
        this.metrics = {
            totalPermits: 0,
            activePermits: 0,
            revokedPermits: 0,
            suspiciousActivity: 0
        };
    }
    
    async startMonitoring(options = {}) {
        const { 
            checkInterval = 60000,
            webhookUrl,
            emailAlert
        } = options;
        
        const monitor = async () => {
            for (const [chain, address] of Object.entries(this.permit3Addresses)) {
                try {
                    await this.checkChain(chain, address);
                } catch (error) {
                    console.error(`Error monitoring ${chain}:`, error);
                }
            }
            
            // Send alerts if needed
            if (this.alerts.length > 0) {
                await this.sendAlerts(webhookUrl, emailAlert);
            }
        };
        
        // Initial check
        await monitor();
        
        // Set up interval
        this.monitorInterval = setInterval(monitor, checkInterval);
        
        return {
            stop: () => clearInterval(this.monitorInterval),
            getMetrics: () => this.metrics,
            getAlerts: () => this.alerts
        };
    }
    
    async checkChain(chain, permit3Address) {
        const provider = new ethers.providers.JsonRpcProvider(RPC_URLS[chain]);
        const permit3 = new ethers.Contract(permit3Address, PERMIT3_ABI, provider);
        
        // Get recent blocks
        const currentBlock = await provider.getBlockNumber();
        const fromBlock = currentBlock - 1000; // Last ~4 hours on Ethereum
        
        // Check for unusual patterns
        const permitFilter = permit3.filters.Permit();
        const permits = await permit3.queryFilter(permitFilter, fromBlock, currentBlock);
        
        // Analyze patterns
        const addressCounts = {};
        const largeAmounts = [];
        
        for (const event of permits) {
            const { owner, modeOrExpiration } = event.args;
            
            // Count permits per address
            addressCounts[owner] = (addressCounts[owner] || 0) + 1;
            
            // Check for large amounts
            const mode = modeOrExpiration & 1n;
            if (mode === 0n) {
                const amount = modeOrExpiration >> 48n;
                if (amount > ethers.utils.parseEther("10000")) {
                    largeAmounts.push({
                        owner,
                        amount: ethers.utils.formatEther(amount),
                        tx: event.transactionHash
                    });
                }
            }
        }
        
        // Generate alerts
        for (const [address, count] of Object.entries(addressCounts)) {
            if (count > 10) {
                this.alerts.push({
                    type: "HIGH_FREQUENCY",
                    chain,
                    address,
                    count,
                    severity: "MEDIUM"
                });
            }
        }
        
        if (largeAmounts.length > 0) {
            this.alerts.push({
                type: "LARGE_AMOUNTS",
                chain,
                transactions: largeAmounts,
                severity: "HIGH"
            });
        }
        
        // Update metrics
        this.metrics.totalPermits += permits.length;
    }
    
    async sendAlerts(webhookUrl, emailAlert) {
        // Send to webhook
        if (webhookUrl) {
            await fetch(webhookUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    alerts: this.alerts,
                    timestamp: new Date().toISOString()
                })
            });
        }
        
        // Send email (implementation depends on email service)
        if (emailAlert) {
            // await sendEmail(emailAlert, "Permit3 Security Alert", this.alerts);
        }
        
        // Clear processed alerts
        this.alerts = [];
    }
}

// Start monitoring
const monitor = new SecurityMonitor(PERMIT3_ADDRESSES);
const monitoring = await monitor.startMonitoring({
    checkInterval: 300000, // 5 minutes
    webhookUrl: "https://your-webhook.com/alerts",
    emailAlert: "security@yourcompany.com"
});
```