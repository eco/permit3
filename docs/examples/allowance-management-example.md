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
    [
        "function permit(address owner, bytes32 salt, uint48 deadline, uint48 timestamp, tuple(uint48 modeOrExpiration, bytes32 tokenKey, address account, uint160 amountDelta)[] permits, bytes signature) external",
        "function hashChainPermits(tuple(uint64 chainId, tuple(uint48 modeOrExpiration, bytes32 tokenKey, address account, uint160 amountDelta)[] permits) chainPermits) pure returns (bytes32)",
        "function allowance(address user, address token, address spender) view returns (uint160 amount, uint48 expiration, uint48 timestamp)"
    ],
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
        tokenKey: ethers.utils.hexZeroPad(USDC_ADDRESS, 32), // an ERC-20's key: its address, left-padded to 32 bytes
        account: DEX_ADDRESS,
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC (6 decimals)
    }]
};

// Create signature elements
const salt = ethers.utils.randomBytes(32);
const deadline = nowSeconds + 3600; // 1 hour for transaction to be included
const timestamp = (await provider.getBlock('latest')).timestamp; // latest block time, not the wall clock

// Set up EIP-712 domain and types
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1,
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

// Calculate hash for chain permits
const permitsHash = await permit3.hashChainPermits(chainPermits);

// Create the value to sign
const value = {
    owner: wallet.address,
    salt,
    deadline,
    timestamp,
    merkleRoot: permitsHash
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
        chainPermits.permits, // the single-chain permit() takes the operations, not the ChainPermits struct
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
        modeOrExpiration: 0, // TransferERC20 mode
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

// Generate hashes and build merkle tree
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const ethHash = await permit3.hashChainPermits(ethereumPermits);
const arbHash = await permit3.hashChainPermits(arbitrumPermits);

// Build merkle tree with ordered leaves
const leaves = [ethHash, arbHash];
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const merkleRoot = '0x' + merkleTree.getRoot().toString('hex');

// Sign with unbalanced root
const value = {
    owner: wallet.address,
    salt,
    deadline,
    timestamp,
    merkleRoot
};

const signature = await wallet._signTypedData(domain, types, value);

// Generate proofs for each chain
// On Ethereum chain (index 0)
const ethereumProof = {
    permits: ethereumPermits,
    proof: merkleTree.getProof(ethHash).map(p => '0x' + p.data.toString('hex'))
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

// On Arbitrum chain (index 1)
const arbitrumProof = {
    permits: arbitrumPermits,
    proof: merkleTree.getProof(arbHash).map(p => '0x' + p.data.toString('hex'))
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
    
    // Check if allowance is locked: a locked allowance has expiration 2
    if (allowance.expiration === 2) {
        console.log("Warning: This allowance is LOCKED");
    }
}

checkAllowance();
```

## Emergency Lockdown

From the owner's own account, `lockdown()` locks (token, spender) pairs at once. It needs no signature or timestamp, and it re-locks a pair that is already locked without reverting:

```javascript
async function emergencyLockdown(pairs) { // pairs: [{ token, spender }]
    const lockdownAbi = ["function lockdown(tuple(address token, address spender)[] approvals) external"];
    const tx = await new ethers.Contract(PERMIT3_ADDRESS, lockdownAbi, wallet).lockdown(pairs);
    await tx.wait();
    console.log("Emergency lockdown successful!");
}

// Example usage: lock each (token, spender) pair you approved
emergencyLockdown([
    { token: USDC_ADDRESS, spender: DEX_ADDRESS },
    // Add more pairs as needed
]);
```

Without gas on the owner's account, sign Lock operations for a relayer instead: see `signEmergencyLock` in [Security Best Practices](../guides/security-best-practices.md#account-locking). Each Lock needs a real `account` (the zero address reverts with `ZeroAccount`), and a Lock on a pair that is already locked reverts its whole permit.