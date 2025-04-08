# 🔏 Permit3 Quick Start Guide 🚀

🧭 [Home](/docs/README.md) > [Guides](/docs/guides/README.md) > Quick Start

This guide will help you quickly integrate Permit3 into your application, enabling cross-chain token approvals and transfers with witness functionality.

## 📋 Prerequisites

- 💻 An Ethereum development environment (Hardhat, Foundry, etc.)
- 🔏 Basic understanding of EIP-712 signatures
- 💰 Familiarity with ERC20 tokens
- 🔌 Access to the Permit3 contract address on your target chain(s)

## 📥 Installation

### Using npm

```bash
npm install @permit3/contracts
```

### Using Foundry

```bash
forge install username/permit3
```

## 🔌 Basic Integration

### 1️⃣  Initialize Permit3 Interface

```solidity
// Existing contracts integrated with Permit2 can work with Permit3 without any changes
IPermit permit = IPermit(PERMIT3_ADDRESS);
permit.transferFrom(from, to, amount, token);

// For Permit3 features
IPermit3 permit3 = IPermit3(PERMIT3_ADDRESS);
```

### 2️⃣  User Setup

Users need to approve Permit3 to spend their tokens (once per token):

```solidity
// User approves Permit3 contract
ERC20(token).approve(PERMIT3_ADDRESS, type(uint256).max);
```

### 3️⃣  Creating and Signing Permits

#### 💸 Simple Token Transfer

```javascript
// JavaScript (ethers.js)
const domain = {
    name: 'Permit3',
    version: '1',
    chainId: chainId,
    verifyingContract: permit3Address
};

const permit = {
    modeOrExpiration: 0, // Transfer mode
    token: tokenAddress,
    account: recipientAddress,
    amountDelta: ethers.utils.parseUnits('10', 18) // 10 tokens
};

const chainPermits = {
    chainId: chainId,
    permits: [permit]
};

const permitData = {
    owner: userAddress,
    salt: ethers.utils.randomBytes(32),
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    timestamp: Math.floor(Date.now() / 1000),
    chain: chainPermits
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
        { name: 'chainId', type: 'uint256' },
        { name: 'permits', type: 'AllowanceOrTransfer[]' }
    ],
    AllowanceOrTransfer: [
        { name: 'modeOrExpiration', type: 'uint48' },
        { name: 'token', type: 'address' },
        { name: 'account', type: 'address' },
        { name: 'amountDelta', type: 'uint160' }
    ]
};

// Calculate the permits hash
const permitsHash = ethers.utils.keccak256(/* hash calculation logic */);

const value = {
    owner: permitData.owner,
    salt: permitData.salt,
    deadline: permitData.deadline,
    timestamp: permitData.timestamp,
    unhingedRoot: permitsHash
};

const signature = await signer._signTypedData(domain, types, value);
```

### 4. Executing Permits

```solidity
// In your contract
function executePermit(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    IPermit3.ChainPermits calldata chainPermits,
    bytes calldata signature
) external {
    permit3.permit(
        owner,
        salt,
        deadline,
        timestamp,
        chainPermits,
        signature
    );
    
    // Now you can use the transferred tokens or the allowance
}
```

## Using Witness Functionality

Witness functionality allows you to include arbitrary data in your permits for enhanced verification.

### 1. Define Your Witness Data

```javascript
// Example: Order data as witness
const orderData = {
    orderId: 12345,
    price: ethers.utils.parseUnits('2000', 18),
    expiration: Math.floor(Date.now() / 1000) + 3600
};

// Hash the order data to create witness
const witness = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
        ['uint256', 'uint256', 'uint256'],
        [orderData.orderId, orderData.price, orderData.expiration]
    )
);

// Define witness type string
const witnessTypeString = "OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration)";
```

### 2. Sign Witness Permit

```javascript
// Add witness types
const types = {
    // ... previous types
    PermitWitnessTransferFrom: [
        { name: 'permitted', type: 'ChainPermits' },
        { name: 'spender', type: 'address' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
        { name: 'timestamp', type: 'uint48' },
        { name: 'data', type: 'OrderData' }
    ],
    OrderData: [
        { name: 'orderId', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'expiration', type: 'uint256' }
    ]
};

// Create and sign witness permit
const witnessValue = {
    permitted: chainPermits,
    spender: userAddress,
    salt: salt,
    deadline: deadline,
    timestamp: timestamp,
    data: orderData
};

const witnessSignature = await signer._signTypedData(domain, types, witnessValue);
```

### 3. Execute Witness Permit

```solidity
function executeWitnessPermit(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    IPermit3.ChainPermits calldata chainPermits,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature,
    OrderData calldata orderData // Your application's data structure
) external {
    // Verify witness matches the order data
    bytes32 expectedWitness = keccak256(abi.encode(
        orderData.orderId,
        orderData.price,
        orderData.expiration
    ));
    
    require(witness == expectedWitness, "Invalid witness data");
    
    // Execute permit with witness
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
    
    // Continue with application logic, using the transferred tokens
    // and the validated order data
}
```

## Cross-Chain Operations

Permit3 supports cross-chain operations with a single signature.

### 1. Create Permits for Multiple Chains

```javascript
// Ethereum permits
const ethPermits = {
    chainId: 1, // Ethereum
    permits: [/* permits for Ethereum */]
};

// Arbitrum permits
const arbPermits = {
    chainId: 42161, // Arbitrum
    permits: [/* permits for Arbitrum */]
};

// Optimism permits
const optPermits = {
    chainId: 10, // Optimism
    permits: [/* permits for Optimism */]
};
```

### 2. Generate and Chain Hashes

```javascript
// Generate root for each chain's permits
const ethRoot = permit3.hashChainPermits(ethPermits);
const arbRoot = permit3.hashChainPermits(arbPermits);
const optRoot = permit3.hashChainPermits(optPermits);

// Create the unhinged root using utility functions from UnhingedMerkleTree library
const unhingedRoot = UnhingedMerkleTree.hashLink(UnhingedMerkleTree.hashLink(ethRoot, arbRoot), optRoot);
```

### 3. Sign and Execute on Each Chain

```javascript
// Sign the combined hash
const signature = signPermit3(owner, salt, deadline, timestamp, unhingedRoot);

// On Ethereum
const ethProof = {
    permits: ethPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethRoot, // The current chain's root
        [], // Subtree proof nodes (empty for the first chain)
        [arbRoot, optRoot] // Following hashes (roots of other chains)
    )
};

permit3.permit(owner, salt, deadline, timestamp, ethProof, signature);

// On Arbitrum
const arbProof = {
    permits: arbPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethRoot, // Pre-hash (root of Ethereum chain)
        [], // Subtree proof nodes
        [optRoot] // Following hashes (root of Optimism chain)
    )
};

permit3.permit(owner, salt, deadline, timestamp, arbProof, signature);

// On Optimism
const optProof = {
    permits: optPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        UnhingedMerkleTree.hashLink(ethRoot, arbRoot), // Pre-hash (combined hash of Ethereum and Arbitrum)
        [], // Subtree proof nodes
        [] // No following hashes for the last chain
    )
};

permit3.permit(owner, salt, deadline, timestamp, optProof, signature);
```

## Common Operations

### Setting an Allowance

```javascript
const permitData = {
    modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours expiration
    token: tokenAddress,
    account: spenderAddress,
    amountDelta: ethers.utils.parseUnits('100', 18) // 100 tokens
};
```

### Decreasing an Allowance

```javascript
const permitData = {
    modeOrExpiration: 1, // Decrease mode
    token: tokenAddress,
    account: spenderAddress,
    amountDelta: ethers.utils.parseUnits('50', 18) // Decrease by 50 tokens
};
```

### Locking an Account

```javascript
const permitData = {
    modeOrExpiration: 2, // Lock mode
    token: tokenAddress,
    account: address(0), // Not used for locking
    amountDelta: 0 // Not used for locking
};
```

### Unlocking an Account

```javascript
const permitData = {
    modeOrExpiration: 3, // Unlock mode
    token: tokenAddress,
    account: address(0), // Not used for unlocking
    amountDelta: 0 // New allowance after unlock
};
```

## Best Practices

1. **Use Unique Salts**: Generate cryptographically secure random values for salts
2. **Set Reasonable Deadlines**: Keep signature validity periods as short as practical
3. **Validate Chain IDs**: Always verify chain IDs match when processing cross-chain permits
4. **Handle Expiration**: Check for expired signatures before attempting to process them
5. **Validate Witness Data**: Verify witness data matches expected values before taking action
6. **Monitor Allowances**: Track allowance changes to prevent unexpected behavior
7. **Test Thoroughly**: Test all permit scenarios, including error cases
8. **Gas Optimization**: Batch related operations when possible

## Next Steps

- Learn about [Witness Functionality](../concepts/witness-functionality.md) in detail
- Explore the [Architecture](../concepts/architecture.md) of Permit3
- Check out the complete [API Reference](../api/api-reference.md)
- See [Examples](../examples/README.md) for common implementation patterns

## Troubleshooting

### Signature Verification Fails

- Ensure domain parameters (name, version, chainId, verifyingContract) are correct
- Verify the signer is the token owner
- Check salt hasn't been used before
- Ensure deadline is in the future
- Verify chainId matches the current chain

### Cross-Chain Issues

- Ensure hash chaining is correct (order matters)
- Verify each chain's proof contains the correct hashes
- Check chainId matches for each chain
- Ensure the same salt and deadline are used across chains

### Witness Verification Problems

- Verify witness type string is properly formatted (must end with ')')
- Ensure witness data matches expected values
- Check EIP-712 type definitions are consistent across frontend and contracts

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Guides](/docs/guides/README.md) | [Guides](/docs/guides/README.md) | [Witness Integration](/docs/guides/witness-integration.md) |