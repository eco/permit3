# Security Best Practices

This guide outlines essential security practices for using Permit3, helping developers and users protect their assets when working with token permissions.

## Fundamental Security Principles

### 1. Limited Permissions Principle

Always grant the minimum level of access required:

```javascript
// BETTER: Time-bound, specific amount approval
const timeRestrictedPermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 3600, // 1 hour expiration
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("100", 6) // Exact amount needed
    }]
};

// AVOID: Unlimited approval with no expiration
const riskyPermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + (365 * 86400), // 1 year
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: ethers.constants.MaxUint256 // Unlimited approval (RISKY)
    }]
};
```

### 2. Defense in Depth

Implement multiple security layers to protect against various attack vectors:

- **Time-bound permissions**: Set appropriate expirations
- **Emergency lockdown**: Implement quick permission revocation
- **Monitoring**: Track all permission changes
- **Allowance limits**: Set maximum approval amounts

## Secure Allowance Management

### Time-Bound Permissions

Always set appropriate expiration times based on the use case:

| Use Case | Recommended Expiration | Why |
|----------|------------------------|-----|
| One-time swap | 10-15 minutes | Minimal exposure window |
| Multi-step process | 1-4 hours | Adequate time for completion |
| Recurring operations | 1-7 days | Balance convenience and security |
| Trusted dApp | Up to 30 days | For trusted, audited applications only |

```javascript
// Function to calculate appropriate expiration
function getExpiration(operationType) {
    const now = Math.floor(Date.now() / 1000);
    
    switch (operationType) {
        case 'swap':
            return now + 15 * 60; // 15 minutes
        case 'multi-step':
            return now + 4 * 60 * 60; // 4 hours
        case 'recurring':
            return now + 7 * 24 * 60 * 60; // 7 days
        case 'trusted':
            return now + 30 * 24 * 60 * 60; // 30 days
        default:
            return now + 60 * 60; // 1 hour default
    }
}
```

### Account Locking

Implement account locking for emergency security control. From the owner's own account, `lockdown()` takes effect immediately and needs no signature or timestamp:

```javascript
// Lock (token, spender) pairs from the owner's own account
async function emergencyLockdown(pairs) { // pairs: [{ token, spender }]
    return permit3.connect(wallet).lockdown(pairs);
}
```

Without gas on the owner's account, sign Lock operations and let a relayer submit them:

```javascript
// Sign Lock operations for a relayer to submit. All pairs go in one permit, so one pair that is already
// locked reverts the whole permit: if that can happen, sign one permit per pair, or use lockdown().
// wallet: the owner's ethers Wallet, connected to the chain's provider
async function signEmergencyLock(pairs) { // pairs: [{ token, spender }]
    const permits = pairs.map(({ token, spender }) => ({
        modeOrExpiration: 2, // Lock mode
        tokenKey: ethers.utils.hexZeroPad(token, 32), // ERC20 or collection: the token address as bytes32
        account: spender, // the account to lock; the zero address reverts with ZeroAccount
        amountDelta: 0 // Not used for lock
    }));

    // Sign the latest block timestamp, not the wall clock. A Lock never reverts for a timestamp
    // ahead of the chain (it stores block.timestamp instead), but Increase and Unlock operations do.
    const timestamp = (await wallet.provider.getBlock('latest')).timestamp;
    const deadline = timestamp + 3600;
    const salt = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    const chainId = (await wallet.provider.getNetwork()).chainId;

    const signature = await signPermit(wallet, domain, { chainId, permits }, salt, deadline, timestamp);

    // The relayer submits: permit3.permit(owner, salt, deadline, timestamp, permits, signature)
    return { owner: wallet.address, salt, deadline, timestamp, permits, signature };
}
```

### Nonce Management

Proper nonce (salt) management is essential:

```javascript
// Generate cryptographically secure random salt
function generateSecureSalt() {
    // Use a CSPRNG for salt generation
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
}

// Check if a salt has been used before signing
async function checkAndSignPermit(permitData) {
    const salt = generateSecureSalt();
    
    // Verify salt is not used
    const isUsed = await permit3.isNonceUsed(wallet.address, salt);
    if (isUsed) {
        // Generate a new salt if this one is already used
        return checkAndSignPermit(permitData);
    }
    
    // Continue with signing using the verified salt
    // ...signing code...
}

// Invalidate multiple salts when a security issue is detected
async function invalidateAllSalts(saltArray) {
    const tx = await permit3.invalidateNonces(saltArray);
    await tx.wait();
    console.log(`Invalidated ${saltArray.length} salts`);
}
```

## Cross-Chain Security

When working with cross-chain permits, additional security considerations apply:

### 1. Chain Synchronization

```javascript
// Use the same salt, deadline, and timestamp across all chains
// providers: the providers of the chains the permit covers, as an array or as an object keyed by chain name
const salt = ethers.utils.randomBytes(32);
const timestamp = await signingTimestamp(providers); // smallest latest-block time of the chains; see "Signing the Timestamp"
const deadline = timestamp + 3600; // 1 hour

// Share these values across all chain operations
```

### 2. Partial Execution Handling

```javascript
// Track execution status across chains
async function trackCrossChainExecution(salt, chains) {
    const results = {};
    
    // Check execution status on each chain
    await Promise.all(chains.map(async (chain) => {
        const provider = getProviderForChain(chain);
        const permit3 = new ethers.Contract(
            PERMIT3_ADDRESSES[chain],
            ["function isNonceUsed(address owner, bytes32 salt) external view returns (bool)"],
            provider
        );
        
        const isExecuted = await permit3.isNonceUsed(wallet.address, salt);
        results[chain] = isExecuted;
    }));
    
    return results;
}

// Based on results, take appropriate action
async function handlePartialExecution(executionResults) {
    const completedChains = Object.keys(executionResults).filter(chain => executionResults[chain]);
    const pendingChains = Object.keys(executionResults).filter(chain => !executionResults[chain]);
    
    if (pendingChains.length > 0) {
        console.log(`Warning: Operation completed on ${completedChains.join(', ')} but not on ${pendingChains.join(', ')}`);
        // Implement recovery strategy
    }
}
```

### 3. Consistent Deadlines

Set longer deadlines for cross-chain operations to account for varying network conditions:

```javascript
// Function to get appropriate deadline for cross-chain operations
function getCrossChainDeadline(chainCount) {
    const baseTime = 3600; // 1 hour base
    const additionalTimePerChain = 1800; // 30 minutes per additional chain
    
    const totalTime = baseTime + (additionalTimePerChain * (chainCount - 1));
    return Math.floor(Date.now() / 1000) + totalTime;
}
```

## Witness Security

When using witness functionality, additional security measures are needed:

### 1. Witness Validation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract SecureWitnessValidator {
    // Maximum age for witness data
    uint256 public immutable MAX_WITNESS_AGE;
    
    constructor(uint256 maxWitnessAge) {
        MAX_WITNESS_AGE = maxWitnessAge;
    }
    
    // Verify witness data
    function verifyTradeData(
        bytes32 witness,
        TradeData calldata tradeData
    ) internal pure returns (bool) {
        bytes32 expectedWitness = keccak256(abi.encode(
            tradeData.orderId,
            tradeData.price,
            tradeData.timestamp,
            tradeData.tokenIn,
            tradeData.tokenOut,
            tradeData.amountIn,
            tradeData.minAmountOut
        ));
        
        return witness == expectedWitness;
    }
    
    // Check witness age
    function isWitnessValid(uint256 witnessTimestamp) internal view returns (bool) {
        return (
            witnessTimestamp <= block.timestamp && // Not future-dated
            block.timestamp - witnessTimestamp <= MAX_WITNESS_AGE // Not too old
        );
    }
}
```

### 2. Witness Type String Security

```javascript
// Properly formatted witness type string
// MUST end with closing parenthesis
const safeWitnessTypeString = "TradeData data)TradeData(uint256 orderId,uint256 price,uint256 timestamp,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut)";

// Function to validate witness type string format
function validateWitnessTypeString(typeString) {
    // Must end with closing parenthesis
    if (!typeString.endsWith(')')) {
        throw new Error("Invalid witness type string: must end with ')'");
    }
    
    // Must contain a variable name and type definition
    const parts = typeString.split(')');
    if (parts.length !== 2) {
        throw new Error("Invalid witness type string format");
    }
    
    const typeNameAndVar = parts[0];
    if (!typeNameAndVar.includes(' ')) {
        throw new Error("Invalid witness type string: must include type name and variable name");
    }
    
    return true;
}
```

## Monitoring and Alerting

Implement monitoring to detect suspicious activity:

```javascript
// Set up event listeners for key events
function monitorPermitEvents() {
    // Listen for Permit events
    permit3.on("Permit", (owner, token, spender, amount, expiration, timestamp, event) => {
        // Check for suspicious activity
        if (amount.eq(ethers.constants.MaxUint256)) {
            sendAlert(`ALERT: Unlimited approval detected for ${owner}`);
        }
        
        if (expiration > Math.floor(Date.now() / 1000) + (30 * 86400)) {
            sendAlert(`ALERT: Long expiration detected for ${owner}`);
        }
        
        // Record permit for tracking
        recordPermit(owner, token, spender, amount, expiration, timestamp);
    });
    
    // Listen for NonceInvalidation events
    permit3.on("NonceInvalidation", (owner, salt, event) => {
        // Multiple invalidations in short time could indicate security issue
        recordNonceInvalidation(owner, salt);
        
        // Check for burst of invalidations
        const recentInvalidations = getRecentInvalidations(owner, 300); // Last 5 minutes
        if (recentInvalidations.length > 5) {
            sendAlert(`ALERT: Multiple nonce invalidations detected for ${owner}`);
        }
    });
}

// Send security alerts
function sendAlert(message) {
    // Implement your preferred alerting mechanism
    console.error(`🚨 ${message}`);
    
    // Example: Send to monitoring service
    fetch('https://alerts.yourdomain.com/webhook', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message, severity: 'high', timestamp: Date.now() })
    });
}
```

## Frontend Security

Client-side security measures to protect users:

### 1. Approval Confirmation

```jsx
// React component for secure approvals
function ApprovalConfirmation({ token, spender, amount, expiration, onConfirm, onCancel }) {
    const [showWarning, setShowWarning] = useState(false);
    
    useEffect(() => {
        // Check for risky approvals
        if (amount.eq(ethers.constants.MaxUint256)) {
            setShowWarning(true);
        }
        
        if (expiration > Math.floor(Date.now() / 1000) + (30 * 86400)) {
            setShowWarning(true);
        }
        
        // Check if spender is verified
        if (!VERIFIED_SPENDERS.includes(spender)) {
            setShowWarning(true);
        }
    }, [token, spender, amount, expiration]);
    
    return (
        <div className="approval-confirmation">
            <h3>Confirm Token Approval</h3>
            
            <div className="approval-details">
                <div>Token: {getTokenSymbol(token)}</div>
                <div>Spender: {getSpenderName(spender) || spender}</div>
                <div>Amount: {formatAmount(amount, token)}</div>
                <div>Expires: {formatDate(expiration)}</div>
            </div>
            
            {showWarning && (
                <div className="warning-box">
                    <h4>⚠️ Security Warning</h4>
                    <p>This approval includes potentially risky settings:</p>
                    <ul>
                        {amount.eq(ethers.constants.MaxUint256) && (
                            <li>Unlimited approval amount</li>
                        )}
                        {expiration > Math.floor(Date.now() / 1000) + (30 * 86400) && (
                            <li>Long expiration time ({formatDuration(expiration)})</li>
                        )}
                        {!VERIFIED_SPENDERS.includes(spender) && (
                            <li>Unverified spender address</li>
                        )}
                    </ul>
                </div>
            )}
            
            <div className="action-buttons">
                <button 
                    className="confirm-button"
                    onClick={onConfirm}
                >
                    Confirm Approval
                </button>
                <button 
                    className="cancel-button"
                    onClick={onCancel}
                >
                    Cancel
                </button>
            </div>
        </div>
    );
}
```

### 2. User Education

```jsx
// Security tips component
function SecurityTips() {
    return (
        <div className="security-tips">
            <h4>Security Tips for Token Approvals</h4>
            <ul>
                <li>Only approve the exact amount you need</li>
                <li>Set the shortest expiration time necessary</li>
                <li>Verify the spender address before approving</li>
                <li>Use the lock feature if you suspect suspicious activity</li>
            </ul>
        </div>
    );
}
```

## Smart Contract Integration Security

When integrating Permit3 into your smart contracts:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract SecurePermit3Integration {
    IPermit3 public immutable permit3;
    
    // Approved tokens and spenders
    mapping(address => bool) public approvedTokens;
    mapping(address => bool) public approvedSpenders;
    
    // Maximum amounts
    mapping(address => uint256) public maxTokenAmounts;
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    // Configure approved tokens and spenders
    function configureApprovedToken(address token, bool approved, uint256 maxAmount) external onlyOwner {
        approvedTokens[token] = approved;
        if (approved) {
            maxTokenAmounts[token] = maxAmount;
        }
    }
    
    function configureApprovedSpender(address spender, bool approved) external onlyOwner {
        approvedSpenders[spender] = approved;
    }
    
    // Securely process permits with validation
    function executeWithPermit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.ChainPermits calldata chainPermits,
        bytes calldata signature
    ) external {
        // 1. Verify correct chain
        require(chainPermits.chainId == block.chainid, "Wrong chain ID");
        
        // 2. Validate permit data
        for (uint i = 0; i < chainPermits.permits.length; i++) {
            IPermit3.AllowanceOrTransfer memory p = chainPermits.permits[i];
            
            // Verify token is approved
            require(approvedTokens[p.token], "Unapproved token");
            
            // Verify spender is approved
            if (p.modeOrExpiration > 0) { // Not a transfer
                require(approvedSpenders[p.account], "Unapproved spender");
            }
            
            // Verify amount is within limits
            if (p.modeOrExpiration > 3 || p.modeOrExpiration == 0) { // Increase or transfer
                require(p.amountDelta <= maxTokenAmounts[p.token], "Amount exceeds maximum");
            }
        }
        
        // 3. Process the permit
        permit3.permit(owner, salt, deadline, timestamp, chainPermits, signature);
        
        // 4. Execute business logic
        // ...
    }
}
```