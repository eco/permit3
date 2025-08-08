# Signature Creation Guide

This guide explains how to create and validate EIP-712 signatures for Permit3, covering standard permits, witness permits, and cross-chain permits.

## Understanding EIP-712 Signatures

Permit3 uses [EIP-712](https://eips.ethereum.org/EIPS/eip-712) for structured data signing, which provides several advantages:

1. **Security**: Shows users exactly what they're signing in a human-readable format
2. **Structure**: Supports complex nested data structures
3. **Type Safety**: Includes type information to prevent misinterpretation
4. **Gas Efficiency**: Optimized for on-chain verification

## Basic Components of EIP-712 Signatures

Every EIP-712 signature consists of:

### 1. Domain Separator

The domain separator uniquely identifies the application, preventing signature reuse across different applications:

```javascript
const domain = {
    name: "Permit3",          // Protocol name
    version: "1",             // Protocol version
    chainId: 1,               // Blockchain ID (Ethereum mainnet)
    verifyingContract: "0x..." // Permit3 contract address
};
```

### 2. Type Definitions

Type definitions describe the structure of the data being signed:

```javascript
const types = {
    // Primary type for standard permits
    Permit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint48' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'merkleRoot', type: 'bytes32' }
    ],
    
    // Supporting types for permit data
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
```

### 3. Values

The actual data being signed, matching the structure defined in the types:

```javascript
const value = {
    owner: "0x123...",              // User's address
    salt: "0x456...",               // Random bytes32 for replay protection
    deadline: 1714732800,           // Unix timestamp when signature expires
    timestamp: 1714646400,          // Current Unix timestamp
    merkleRoot: "0x789..."        // Hash of permit data
};
```

## Signature Creation Process

### Step 1: Set Up Libraries

```javascript
// For ethers.js v5
const { ethers } = require('ethers');

// Set up provider and signer
const provider = new ethers.providers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY');
const signer = new ethers.Wallet('0x...PRIVATE_KEY...', provider);

// For web applications using browser wallets
const provider = new ethers.providers.Web3Provider(window.ethereum);
await provider.send('eth_requestAccounts', []);
const signer = provider.getSigner();
```

### Step 2: Create Permit Data

```javascript
// Standard permit data
const chainPermits = {
    chainId: 1, // Ethereum mainnet
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24h from now
        token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
        account: "0x1111111111111111111111111111111111111111", // Spender
        amountDelta: ethers.utils.parseUnits("1000", 6) // 1000 USDC
    }]
};
```

### Step 3: Calculate Hash for Permit Data

```javascript
// Initialize Permit3 contract
const permit3 = new ethers.Contract(
    PERMIT3_ADDRESS,
    ["function hashChainPermits(tuple(uint256,tuple(uint48,address,address,uint160)[]) permits) external pure returns (bytes32)"],
    signer
);

// Calculate hash for permit data
const permitsHash = await permit3.hashChainPermits(chainPermits);
```

### Step 4: Define Signature Elements

```javascript
// Generate a random salt (nonce)
const salt = ethers.utils.randomBytes(32);

// Set the deadline (signature expiration time)
const now = Math.floor(Date.now() / 1000);
const deadline = now + 3600; // 1 hour from now

// Set the operation timestamp
const timestamp = now;

// Create the value to sign
const value = {
    owner: await signer.getAddress(),
    salt,
    deadline,
    timestamp,
    merkleRoot: permitsHash // For standard permit, this is just the permits hash
};

// Create EIP-712 domain
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
    verifyingContract: PERMIT3_ADDRESS
};

// Define types for standard permit
const types = {
    Permit3: [
        { name: 'owner', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint48' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'merkleRoot', type: 'bytes32' }
    ]
};
```

### Step 5: Sign the Message

```javascript
// Sign using ethers.js
const signature = await signer._signTypedData(domain, types, value);

// Alternative for web3.js
// const data = JSON.stringify({
//     types: {
//         EIP712Domain: [
//             { name: 'name', type: 'string' },
//             { name: 'version', type: 'string' },
//             { name: 'chainId', type: 'uint256' },
//             { name: 'verifyingContract', type: 'address' }
//         ],
//         ...types
//     },
//     primaryType: 'Permit3',
//     domain,
//     message: value
// });
// 
// const signature = await ethereum.request({
//     method: 'eth_signTypedData_v4',
//     params: [userAddress, data],
// });
```

### Step 6: Execute the Permit

```javascript
// Execute the permit
const tx = await permit3.permit(
    value.owner,
    value.salt,
    value.deadline,
    value.timestamp,
    chainPermits,
    signature
);

await tx.wait();
console.log("Permit executed successfully:", tx.hash);
```

## Witness Signatures

For permits that include witness data:

### Step 1: Define Witness Data Structure

```typescript
// Example: Order data for a DEX trade
interface OrderData {
    orderId: number;
    price: bigint;
    expiration: number;
    tokenIn: string;
    tokenOut: string;
    amountIn: bigint;
    minAmountOut: bigint;
}

// Create witness data instance
const orderData: OrderData = {
    orderId: 12345,
    price: BigInt(2000 * 1e18),
    expiration: Math.floor(Date.now() / 1000) + 3600,
    tokenIn: USDC_ADDRESS,
    tokenOut: WETH_ADDRESS,
    amountIn: BigInt(1000 * 1e6),
    minAmountOut: BigInt(0.5 * 1e18)
};
```

### Step 2: Create Witness Hash and Type String

```javascript
// Hash the witness data according to its structure
const witness = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
        [
            "uint256", "uint256", "uint256", 
            "address", "address", "uint256", "uint256"
        ],
        [
            orderData.orderId, 
            orderData.price, 
            orderData.expiration,
            orderData.tokenIn,
            orderData.tokenOut,
            orderData.amountIn,
            orderData.minAmountOut
        ]
    )
);

// Define the witness type string (IMPORTANT: must end with ')')
const witnessTypeString = "OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut)";
```

### Step 3: Define Witness Permit Types

```javascript
// Types for witness permit
const witnessTypes = {
    PermitWitness: [
        { name: 'permitted', type: 'ChainPermits' },
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint48' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'witness', type: 'bytes32' }
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
```

### Step 4: Create and Sign Witness Permit Value

```javascript
// Create witness permit value
const witnessValue = {
    permitted: chainPermits,
    owner: await signer.getAddress(),
    spender: DEX_ADDRESS,
    salt,
    deadline,
    timestamp,
    witness
};

// Sign witness permit
const witnessSignature = await signer._signTypedData(domain, witnessTypes, witnessValue);
```

### Step 5: Execute Witness Permit

```javascript
// Execute the witness permit
const tx = await permit3.permitWitness(
    witnessValue.owner,
    witnessValue.salt,
    witnessValue.deadline,
    witnessValue.timestamp,
    witnessValue.permitted,
    witnessValue.witness,
    witnessTypeString,
    witnessSignature
);

await tx.wait();
console.log("Witness permit executed:", tx.hash);
```

## Cross-Chain Signatures

For permits that span multiple chains:

### Step 1: Create Chain-Specific Permits

```javascript
// Define permits for each chain
const ethereumPermits = {
    chainId: 1,
    permits: [/* Ethereum operations */]
};

const arbitrumPermits = {
    chainId: 42161,
    permits: [/* Arbitrum operations */]
};
```

### Step 2: Calculate Hashes and Create Unbalanced Root

```javascript
// Calculate hashes for each chain
const ethereumHash = await ethereumPermit3.hashChainPermits(ethereumPermits);
const arbitrumHash = await arbitrumPermit3.hashChainPermits(arbitrumPermits);

// Create the unbalanced root
const merkleRoot = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
        ['bytes32', 'bytes32'],
        [ethereumHash, arbitrumHash]
    )
);

// Create signature value with unbalanced root
const value = {
    owner: await signer.getAddress(),
    salt,
    deadline,
    timestamp,
    merkleRoot
};
```

### Step 3: Sign and Execute

```javascript
// Sign with the same process as standard permits
const signature = await signer._signTypedData(domain, types, value);

// On each chain, execute with the appropriate proof
// (See Cross-Chain Permit Guide for proof creation details)
```

## Signature Verification

For client-side verification:

```javascript
// Function to verify a permit signature
async function verifyPermitSignature(
    owner,
    salt,
    deadline,
    timestamp,
    chainPermits,
    signature
) {
    // Calculate the permits hash
    const permitsHash = await permit3.hashChainPermits(chainPermits);
    
    // Create the EIP-712 domain
    const domain = {
        name: "Permit3",
        version: "1",
        chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
        verifyingContract: PERMIT3_ADDRESS
    };
    
    // Create the types
    const types = {
        Permit3: [
            { name: 'owner', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint48' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'merkleRoot', type: 'bytes32' }
        ]
    };
    
    // Create the value
    const value = {
        owner,
        salt,
        deadline,
        timestamp,
        merkleRoot: permitsHash
    };
    
    // Calculate the digest
    const hash = ethers.utils._TypedDataEncoder.hash(domain, types, value);
    
    // Recover the signer address
    const recoveredAddress = ethers.utils.recoverAddress(hash, signature);
    
    // Verify the recovered address matches the claimed owner
    return {
        isValid: recoveredAddress.toLowerCase() === owner.toLowerCase(),
        recoveredAddress,
        expectedAddress: owner
    };
}
```

## Salt (Nonce) Management

Best practices for managing salts:

```javascript
// Generate a truly random salt
function generateSalt() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
}

// Check if a salt is already used
async function isSaltUsed(owner, salt) {
    return await permit3.isNonceUsed(owner, salt);
}

// Invalidate multiple unused salts
async function invalidateUnusedSalts(salts) {
    // First check which salts are unused
    const unusedSalts = [];
    for (const salt of salts) {
        if (!(await isSaltUsed(wallet.address, salt))) {
            unusedSalts.push(salt);
        }
    }
    
    if (unusedSalts.length > 0) {
        // Invalidate all unused salts in one transaction
        const tx = await permit3.invalidateNonces(unusedSalts);
        await tx.wait();
        return true;
    }
    
    return false;
}
```

## Common Issues and Solutions

### 1. Invalid Signature Errors

| Error | Possible Causes | Solution |
|-------|----------------|----------|
| `InvalidSignature` | Wrong signer | Verify signer matches owner |
| | Incorrect domain parameters | Ensure name, version, chainId, and contract address are correct |
| | Wrong data structure | Verify types match contract definitions |

### 2. SignatureExpired Error

```javascript
// Check if a signature is expired
function isSignatureExpired(deadline) {
    return deadline < Math.floor(Date.now() / 1000);
}

// Create deadline with buffer for network congestion
function createDeadlineWithBuffer(minutes) {
    const nowSeconds = Math.floor(Date.now() / 1000);
    return nowSeconds + (minutes * 60);
}
```

### 3. WrongChainId Error

```javascript
// Ensure chainId matches the current chain
async function validateChainId(chainPermits) {
    const networkChainId = await provider.getNetwork().then(n => n.chainId);
    return chainPermits.chainId === networkChainId;
}
```

### 4. NonceAlreadyUsed Error

```javascript
// Generate and verify a salt is unused before signing
async function generateUnusedSalt() {
    let salt;
    do {
        salt = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    } while (await permit3.isNonceUsed(wallet.address, salt));
    return salt;
}
```

## Security Best Practices

1. **Salt Management**: Always use cryptographically secure random values for salts
2. **Reasonable Deadlines**: Set deadlines appropriate to the operation (shorter for sensitive operations)
3. **Account Switching**: Clear cached signatures when users switch accounts
4. **Chain Validation**: Always verify the chainId before submitting transactions
5. **Signature Validation**: Verify signatures client-side before submitting to avoid wasting gas on invalid signatures

## Conclusion

This guide covers the essential aspects of creating and validating signatures for Permit3. By following these practices, you can securely implement signature-based token approvals in your application.

For more complex examples and patterns, refer to the [Integration Example](../examples/integration-example.md) documentation.