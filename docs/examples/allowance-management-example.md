# Allowance Management Example

This example demonstrates how to manage token allowances using Permit3's flexible permission system.

## Basic Allowance Management

### Setting an Initial Allowance

Let's set an initial allowance of 1000 USDC for a DEX with a 24-hour expiration:

```javascript
// Import libraries
const { ethers } = require("ethers");
const provider = new ethers.providers.JsonRpcProvider("https://mainnet.infura.io/v3/YOUR_INFURA_KEY");
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Set up variables
const PERMIT3_ADDRESS = "0x0000000000000000000000000000000000000000"; // Replace with actual address
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const DEX_ADDRESS = "0xDEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1DEF1"; // Example DEX address

// Create Permit3 interface
const permit3 = new ethers.Contract(
    PERMIT3_ADDRESS,
    ["function permit(address owner, bytes32 salt, uint256 deadline, uint48 timestamp, tuple(uint256 chainId, tuple(uint48 modeOrExpiration, address token, address account, uint160 amountDelta)[] permits) chain, bytes signature) external"],
    wallet
);

// Calculate timestamp and expiration
const nowSeconds = Math.floor(Date.now() / 1000);
const expiration = nowSeconds + 86400; // 24 hours from now

// Set up the permit data
const chainPermits = {
    chainId: 1, // Ethereum mainnet
    permits: [{
        modeOrExpiration: expiration,
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC (6 decimals)
    }]
};

// Create signature elements
const salt = ethers.utils.randomBytes(32);
const deadline = nowSeconds + 3600; // 1 hour for transaction to be included
const timestamp = nowSeconds;

// Set up EIP-712 domain and types
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1,
    verifyingContract: PERMIT3_ADDRESS
};

const types = {
    SignedPermit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'unhingedRoot', type: 'bytes32' }
    ],
    ChainPermits: [
        { name: 'chainId', type: 'uint64' },
        { name: 'permits', type: 'AllowanceOrTransfer[]' }
    ],
    AllowanceOrTransfer: [
        { name: 'modeOrExpiration', type: 'uint48' },
        { name: 'token', type: 'address' },
        { name: 'account', type: 'address' },
        { name: 'amountDelta', type: 'uint160' }
    ]
};

// Calculate hash for chain permits
const permitsHash = await permit3.hashChainPermits(chainPermits);

// Create the value to sign
const value = {
    owner: wallet.address,
    salt,
    deadline,
    timestamp,
    unhingedRoot: permitsHash
};

// Sign the message
const signature = await wallet._signTypedData(domain, types, value);

// Send the transaction
async function setAllowance() {
    const tx = await permit3.permit(
        wallet.address,
        salt,
        deadline,
        timestamp,
        chainPermits,
        signature
    );
    
    console.log("Transaction sent:", tx.hash);
    await tx.wait();
    console.log("Allowance set successfully!");
}

setAllowance();
```

## Multiple Allowance Operations

You can combine multiple operations in a single transaction:

```javascript
// Multiple operations in one transaction
const chainPermits = {
    chainId: 1,
    permits: [
        // Set 1000 USDC allowance for DEX1
        {
            modeOrExpiration: expiration,
            token: USDC_ADDRESS,
            account: DEX1_ADDRESS,
            amountDelta: ethers.utils.parseUnits("1000", 6)
        },
        // Set 500 DAI allowance for DEX2
        {
            modeOrExpiration: expiration,
            token: DAI_ADDRESS,
            account: DEX2_ADDRESS,
            amountDelta: ethers.utils.parseUnits("500", 18) // DAI has 18 decimals
        },
        // Set unlimited WETH allowance for DEX3
        {
            modeOrExpiration: expiration,
            token: WETH_ADDRESS,
            account: DEX3_ADDRESS,
            amountDelta: ethers.constants.MaxUint256 // Unlimited approval
        }
    ]
};
```

## Allowance Operations by Type

Let's explore each type of allowance operation:

### 1. Increase Allowance

```javascript
// Increase allowance by 500 USDC
const increasePermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: expiration,
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("500", 6)
    }]
};
```

### 2. Decrease Allowance

```javascript
// Decrease allowance by 200 USDC
const decreasePermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: 1, // Decrease mode
        token: USDC_ADDRESS,
        account: DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("200", 6)
    }]
};
```

### 3. Lock Allowances

```javascript
// Lock all USDC allowances (emergency function)
const lockPermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: 2, // Lock mode
        token: USDC_ADDRESS,
        account: ethers.constants.AddressZero, // Not used for locking
        amountDelta: 0 // Not used for locking
    }]
};
```

### 4. Unlock Allowances

```javascript
// Unlock USDC (requires subsequent increase operation to set allowance)
const unlockPermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: 3, // Unlock mode
        token: USDC_ADDRESS,
        account: ethers.constants.AddressZero, // Not used for unlocking
        amountDelta: 0 // Not used for unlocking
    }]
};
```

### 5. Direct Transfer

```javascript
// Transfer 50 USDC to recipient
const transferPermit = {
    chainId: 1,
    permits: [{
        modeOrExpiration: 0, // Transfer mode
        token: USDC_ADDRESS,
        account: RECIPIENT_ADDRESS,
        amountDelta: ethers.utils.parseUnits("50", 6)
    }]
};
```

## Advanced: Managing Allowances Across Chains

To manage allowances across multiple chains with a single signature:

```javascript
// Define permits for each chain
const ethereumPermits = {
    chainId: 1,
    permits: [{
        modeOrExpiration: expiration,
        token: ETH_USDC_ADDRESS,
        account: ETH_DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("1000", 6)
    }]
};

const arbitrumPermits = {
    chainId: 42161,
    permits: [{
        modeOrExpiration: expiration,
        token: ARB_USDC_ADDRESS,
        account: ARB_DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("1000", 6)
    }]
};

// Generate hashes and create unhinged root
const ethHash = await permit3.hashChainPermits(ethereumPermits);
const arbHash = await permit3.hashChainPermits(arbitrumPermits);
const unhingedRoot = UnhingedMerkleTree.hashLink(ethHash, arbHash);

// Sign with unhinged root
const value = {
    owner: wallet.address,
    salt,
    deadline,
    timestamp,
    unhingedRoot
};

const signature = await wallet._signTypedData(domain, types, value);

// On Ethereum chain
const ethereumProof = {
    permits: ethereumPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethers.constants.HashZero, // No preHash for first chain
        [],
        [arbHash] // Following hash
    )
};

// Execute on Ethereum
const ethTx = await ethereumPermit3.permit(
    wallet.address,
    salt,
    deadline,
    timestamp,
    ethereumProof,
    signature
);

// On Arbitrum chain
const arbitrumProof = {
    permits: arbitrumPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethHash, // preHash is Ethereum hash
        [],
        [] // No following hashes
    )
};

// Execute on Arbitrum
const arbTx = await arbitrumPermit3.permit(
    wallet.address,
    salt,
    deadline,
    timestamp,
    arbitrumProof,
    signature
);
```

## Checking Allowances

To check current allowances:

```javascript
async function checkAllowance() {
    const allowance = await permit3.allowance(
        wallet.address,
        USDC_ADDRESS,
        DEX_ADDRESS
    );
    
    console.log("Current allowance:", ethers.utils.formatUnits(allowance.amount, 6), "USDC");
    console.log("Expiration:", new Date(allowance.expiration * 1000).toLocaleString());
    console.log("Last updated:", new Date(allowance.timestamp * 1000).toLocaleString());
    
    // Check if allowance is locked
    if (allowance.timestamp === ethers.constants.MaxUint48) {
        console.log("Warning: This allowance is LOCKED");
    }
}

checkAllowance();
```

## Emergency Lockdown

Implement an emergency lockdown function that locks all token approvals:

```javascript
async function emergencyLockdown(tokenAddresses) {
    // Create lock permits for all tokens
    const lockPermits = {
        chainId: (await provider.getNetwork()).chainId,
        permits: tokenAddresses.map(token => ({
            modeOrExpiration: 2, // Lock mode
            token,
            account: ethers.constants.AddressZero,
            amountDelta: 0
        }))
    };
    
    // Generate salt, etc.
    const salt = ethers.utils.randomBytes(32);
    const nowSeconds = Math.floor(Date.now() / 1000);
    const deadline = nowSeconds + 3600;
    const timestamp = nowSeconds;
    
    // Calculate hash and sign
    const permitsHash = await permit3.hashChainPermits(lockPermits);
    
    const value = {
        owner: wallet.address,
        salt,
        deadline,
        timestamp,
        unhingedRoot: permitsHash
    };
    
    const signature = await wallet._signTypedData(domain, types, value);
    
    // Submit with high gas price for faster inclusion
    const tx = await permit3.permit(
        wallet.address,
        salt,
        deadline,
        timestamp,
        lockPermits,
        signature,
        { gasPrice: ethers.utils.parseUnits("100", "gwei") }
    );
    
    await tx.wait();
    console.log("Emergency lockdown successful!");
}

// Example usage
emergencyLockdown([
    USDC_ADDRESS,
    DAI_ADDRESS,
    WETH_ADDRESS,
    // Add more token addresses as needed
]);
```

## Conclusion

Permit3's flexible allowance system provides comprehensive token permission management with features like:

- Increasing/decreasing allowances
- Time-bound permissions
- Emergency locking/unlocking
- Direct transfers
- Cross-chain management

These features allow users to maintain precise control over their token permissions while minimizing on-chain transactions.