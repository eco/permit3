# Permit3 Witness Integration Guide

This guide explains how to integrate Permit3's witness functionality into your application, allowing for enhanced verification and conditional permissions.

## What is Witness Functionality?

Witness functionality allows you to attach arbitrary data to a permit, which must be verified during permit execution. This enables complex permission patterns such as:

- Trade execution with specific price limits
- Conditional permissions based on external data
- Context-specific approvals
- Multi-step transaction validation

## How Witness Works

At a high level, witness functionality works by:

1. Including a witness hash in the signature data
2. Defining a type string that describes the witness data structure
3. Verifying that the provided witness matches expected data during execution

## Implementation Steps

### Step 1: Define Your Witness Data Structure

First, define the data structure that will be used as a witness:

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
```

### Step 2: Create the Witness Type String

Create an EIP-712 compatible type string for your witness data:

```typescript
// Note: This follows EIP-712 format and MUST end with a closing parenthesis
const witnessTypeString = "OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut)";
```

The format is `<PrimaryTypeName> <VariableName>)<TypeDefinitions>`, where:
- `<PrimaryTypeName>` is the name of your witness data type (e.g., "OrderData")
- `<VariableName>` is the parameter name (e.g., "data")
- `<TypeDefinitions>` is the EIP-712 type definition

### Step 3: Generate the Witness Hash

Hash your witness data according to EIP-712 encoding rules:

```typescript
// Sample order data
const orderData: OrderData = {
    orderId: 12345,
    price: BigInt(2000 * 1e18),         // 2000 USD price, decimals 18
    expiration: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
    tokenIn: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
    tokenOut: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
    amountIn: BigInt(1000 * 1e6),       // 1000 USDC
    minAmountOut: BigInt(0.5 * 1e18)     // 0.5 WETH minimum
};

// Function to hash order data according to EIP-712
function hashOrderData(order: OrderData): string {
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            [
                "uint256", "uint256", "uint256", 
                "address", "address", "uint256", "uint256"
            ],
            [
                order.orderId, 
                order.price, 
                order.expiration,
                order.tokenIn,
                order.tokenOut,
                order.amountIn,
                order.minAmountOut
            ]
        )
    );
}

// Create the witness hash
const witness = hashOrderData(orderData);
```

### Step 4: Set Up EIP-712 Signing

Create the domain and types for EIP-712 signature:

```typescript
// Define EIP-712 domain
const domain = {
    name: "Permit3",
    version: "1",
    chainId: 1, // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
    verifyingContract: PERMIT3_ADDRESS
};

// Define EIP-712 types for witness permit
const types = {
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

// If including the witness data directly in the signature, extend the types:
const extendedTypes = {
    ...types,
    OrderData: [
        { name: 'orderId', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'expiration', type: 'uint256' },
        { name: 'tokenIn', type: 'address' },
        { name: 'tokenOut', type: 'address' },
        { name: 'amountIn', type: 'uint256' },
        { name: 'minAmountOut', type: 'uint256' }
    ]
};
```

### Step 5: Create and Sign the Permit

```typescript
// Create permit data for USDC approval
const chainPermits = {
    chainId,
    permits: [{
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400, // 24 hours
        token: orderData.tokenIn, // USDC
        account: DEX_ADDRESS,
        amountDelta: orderData.amountIn // 1000 USDC
    }]
};

// Create salt, deadline, and timestamp
const salt = ethers.utils.randomBytes(32);
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
const timestamp = Math.floor(Date.now() / 1000);

// Data to sign
const value = {
    permitted: chainPermits,
    owner: walletAddress,
    spender: DEX_ADDRESS,
    salt,
    deadline,
    timestamp,
    witness
};

// Sign the data
const signature = await signer._signTypedData(domain, types, value);
```

### Step 6: Execute with Witness Verification

#### Client-Side

```typescript
// Execute permit with witness
const permitWithWitnessTx = await permit3.permitWitness(
    walletAddress,
    salt,
    deadline,
    timestamp,
    chainPermits,
    witness,
    witnessTypeString,
    signature
);

await permitWithWitnessTx.wait();
console.log("Permit with witness executed:", permitWithWitnessTx.hash);
```

#### Contract-Side (Custom Verifier)

Implement a contract that verifies the witness data matches expected values:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract DexWithWitness {
    IPermit3 public immutable permit3;
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    struct OrderData {
        uint256 orderId;
        uint256 price;
        uint256 expiration;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
    }
    
    function executeOrderWithPermit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        IPermit3.ChainPermits calldata chainPermits,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature,
        OrderData calldata orderData
    ) external {
        // 1. Verify the witness matches the order data
        bytes32 expectedWitness = keccak256(abi.encode(
            orderData.orderId,
            orderData.price,
            orderData.expiration,
            orderData.tokenIn,
            orderData.tokenOut,
            orderData.amountIn,
            orderData.minAmountOut
        ));
        
        require(witness == expectedWitness, "Witness does not match order data");
        
        // 2. Verify order is still valid
        require(block.timestamp <= orderData.expiration, "Order expired");
        
        // 3. Execute permit with witness
        permit3.permitWitness(
            owner,
            salt,
            deadline,
            timestamp,
            chainPermits,
            witness,
            witnessTypeString,
            signature
        );
        
        // 4. Execute the trade logic
        // ... DEX swap implementation ...
        
        // 5. Verify output amount meets minimum
        // ... Check output amount against orderData.minAmountOut ...
    }
}
```

## Advanced: Using Witness with Cross-Chain Operations

For cross-chain operations, you can combine witness functionality with unbalanced proofs:

```typescript
// Create the permit with witness for cross-chain operation
const tx = await permit3.permitWitness(
    owner,
    salt,
    deadline,
    timestamp,
    permits, // ChainPermits for current chain
    proof,   // bytes32[] merkle proof array
    witness,
    witnessTypeString,
    signature
);
```

The same witness is verified on each chain, allowing for cross-chain conditional permissions.

## Security Considerations

### 1. Witness Type String Validation

The witness type string must:
- End with a closing parenthesis ')'  
- Follow EIP-712 type format
- Match the actual data structure being hashed

Invalid type strings will cause transaction failure with `InvalidWitnessTypeString` error.

### 2. Replay Protection

Each witness permit uses a unique salt (nonce) to prevent replay attacks. Ensure your implementation generates unique salts for each transaction.

### 3. Deadlines

Always set appropriate deadlines for permits, especially with witness data that may have time-sensitive information.

### 4. Data Validation

Always validate witness data on-chain before taking action based on it:
- Verify prices are within acceptable ranges
- Check expirations
- Validate order parameters

## Performance Optimization

### Gas Usage

Witness verification adds approximately 15,000-20,000 gas overhead compared to standard permits. To optimize:

1. Keep witness data compact
2. Only include essential fields in the witness
3. For complex operations, use a hash of data stored off-chain

### Batching

Combine multiple operations in a single permit to amortize the witness verification cost:

```typescript
const batchedPermits = {
    chainId,
    permits: [
        // Operation 1
        { modeOrExpiration: future, token: USDC, account: DEX, amountDelta: 1000e6 },
        // Operation 2
        { modeOrExpiration: future, token: WETH, account: DEX, amountDelta: 1e18 },
        // ... more operations
    ]
};
```
