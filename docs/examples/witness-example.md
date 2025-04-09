<a id="witness-example-top"></a>
# 🔏 Permit3 Witness Functionality Example 🧩

###### Quick Navigation: [Use Case](#use-case-orderbook-dex-with-witness-data) | [Order Structure](#step-1-define-order-structure) | [Witness Data](#step-2-witness-data-encoding-and-verification) | [Order Execution](#step-3-execute-order-with-witness) | [Client-Side](#step-4-client-side-order-creation-and-signing) | [Multi-Signature Example](#advanced-example-multi-signature-order-execution) | [Key Takeaways](#summary-and-key-takeaways)

🧭 [Home](/docs/README.md) > [Examples](/docs/examples/README.md) > Witness Example

This example demonstrates how to implement and use Permit3's witness functionality in a decentralized exchange scenario.

<a id="use-case-orderbook-dex-with-witness-data"></a>
## 📊 Use Case: Orderbook DEX with Witness Data

In this example, we'll create a decentralized exchange where orders are submitted off-chain and executed on-chain using Permit3's witness functionality to verify order parameters.

<a id="step-1-define-order-structure"></a>
### 📝  Step 1: Define Order Structure

First, we define the order structure that will be encoded in the witness data:

```solidity
// OrderBook.sol
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract OrderBook {
    IPermit3 public immutable permit3;
    
    struct Order {
        uint256 orderId;
        address maker;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 expiration;
        bytes32 salt;
    }
    
    mapping(bytes32 => bool) public executedOrders;
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    // Order functions will be implemented below
}
```

<a id="step-2-witness-data-encoding-and-verification"></a>
### 🔍  Step 2: Witness Data Encoding and Verification

Next, we implement functions to encode and verify order data as witness:

```solidity
// Within OrderBook.sol

// Generate witness from order data
function getOrderWitness(Order memory order) public pure returns (bytes32) {
    return keccak256(abi.encode(
        order.orderId,
        order.maker,
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut,
        order.expiration
    ));
}

// Get witness type string for EIP-712 signature
function getWitnessTypeString() public pure returns (string memory) {
    return "Order order)Order(uint256 orderId,address maker,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut,uint256 expiration)";
}
```

<a id="step-3-execute-order-with-witness"></a>
### Step 3: Execute Order with Witness

Now we implement the order execution function that uses Permit3's witness functionality:

```solidity
// Within OrderBook.sol

function executeOrder(
    Order memory order,
    address maker,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    IPermit3.ChainPermits memory chainPermits,
    bytes32 witness,
    bytes calldata signature
) external {
    // 1. Check order hasn't expired
    require(block.timestamp <= order.expiration, "Order expired");
    
    // 2. Generate order hash (used as unique identifier)
    bytes32 orderHash = keccak256(abi.encode(
        order.orderId,
        order.maker,
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut,
        order.expiration,
        order.salt
    ));
    
    // 3. Check order hasn't been executed
    require(!executedOrders[orderHash], "Order already executed");
    
    // 4. Verify witness matches the order data
    bytes32 expectedWitness = getOrderWitness(order);
    require(witness == expectedWitness, "Invalid witness data");
    
    // 5. Verify maker matches
    require(maker == order.maker, "Invalid maker");
    
    // 6. Verify transfer details
    require(chainPermits.permits.length == 1, "Invalid permit count");
    require(chainPermits.permits[0].token == order.tokenIn, "Invalid token");
    require(chainPermits.permits[0].account == address(this), "Invalid recipient");
    require(chainPermits.permits[0].amountDelta == order.amountIn, "Invalid amount");
    require(chainPermits.permits[0].modeOrExpiration == 0, "Invalid mode");
    
    // 7. Execute permit with witness
    permit3.permitWitnessTransferFrom(
        maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        getWitnessTypeString(),
        signature
    );
    
    // 8. Mark order as executed
    executedOrders[orderHash] = true;
    
    // 9. Execute the trade
    uint256 outputAmount = _executeTrade(
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut
    );
    
    // 10. Send output tokens to maker
    _transferTokens(order.tokenOut, order.maker, outputAmount);
    
    emit OrderExecuted(orderHash, order.maker, outputAmount);
}

function _executeTrade(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut
) internal returns (uint256) {
    // Implementation of actual trade logic (using AMM, aggregator, etc.)
    // ...
    return calculatedOutputAmount;
}

function _transferTokens(
    address token,
    address recipient,
    uint256 amount
) internal {
    // Implementation of token transfer
    // ...
}

event OrderExecuted(
    bytes32 indexed orderHash,
    address indexed maker,
    uint256 outputAmount
);
```

<a id="step-4-client-side-order-creation-and-signing"></a>
### Step 4: Client-Side Order Creation and Signing

Here's how to create and sign an order using ethers.js:

```javascript
// order-signing.js
const ethers = require('ethers');

async function createAndSignOrder(
    signer,
    permit3Address,
    orderBookAddress,
    order
) {
    // 1. Create permit data
    const chainPermits = {
        chainId: await signer.getChainId(),
        permits: [{
            modeOrExpiration: 0, // Transfer mode
            token: order.tokenIn,
            account: orderBookAddress,
            amountDelta: order.amountIn
        }]
    };
    
    // 2. Create salt and deadline
    const salt = ethers.utils.randomBytes(32);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 3. Create witness
    const abiCoder = new ethers.utils.AbiCoder();
    const witness = ethers.utils.keccak256(
        abiCoder.encode(
            ['uint256', 'address', 'address', 'address', 'uint256', 'uint256', 'uint256'],
            [
                order.orderId,
                order.maker,
                order.tokenIn,
                order.tokenOut,
                order.amountIn,
                order.minAmountOut,
                order.expiration
            ]
        )
    );
    
    // 4. Set up EIP-712 domain
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: await signer.getChainId(),
        verifyingContract: permit3Address
    };
    
    // 5. Define types
    const types = {
        PermitWitnessTransferFrom: [
            { name: 'permitted', type: 'ChainPermits' },
            { name: 'spender', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint256' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'order', type: 'Order' }
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
        ],
        Order: [
            { name: 'orderId', type: 'uint256' },
            { name: 'maker', type: 'address' },
            { name: 'tokenIn', type: 'address' },
            { name: 'tokenOut', type: 'address' },
            { name: 'amountIn', type: 'uint256' },
            { name: 'minAmountOut', type: 'uint256' },
            { name: 'expiration', type: 'uint256' }
        ]
    };
    
    // 6. Create value to sign
    const value = {
        permitted: chainPermits,
        spender: order.maker,
        salt: salt,
        deadline: deadline,
        timestamp: timestamp,
        order: {
            orderId: order.orderId,
            maker: order.maker,
            tokenIn: order.tokenIn,
            tokenOut: order.tokenOut,
            amountIn: order.amountIn,
            minAmountOut: order.minAmountOut,
            expiration: order.expiration
        }
    };
    
    // 7. Sign the typed data
    const signature = await signer._signTypedData(domain, types, value);
    
    // 8. Return all data needed for execution
    return {
        order,
        maker: order.maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        signature
    };
}
```

<a id="step-5-execute-order-from-client"></a>
### Step 5: Execute Order from Client

Here's how to execute an order using the signed data:

```javascript
// order-execution.js
async function executeOrder(orderBookContract, signedOrderData) {
    const {
        order,
        maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        signature
    } = signedOrderData;
    
    // Execute the order
    const tx = await orderBookContract.executeOrder(
        order,
        maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        signature
    );
    
    return await tx.wait();
}
```

<a id="advanced-example-multi-signature-order-execution"></a>
## Advanced Example: Multi-Signature Order Execution

This example extends the basic order execution to require multiple signatures for high-value orders.

### Step 1: Define Multi-Signature Order Structure

```solidity
// MultiSigOrderBook.sol
pragma solidity ^0.8.0;

import "@permit3/interfaces/IPermit3.sol";

contract MultiSigOrderBook {
    IPermit3 public immutable permit3;
    
    struct MultiSigOrder {
        uint256 orderId;
        address maker;
        address approver;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 expiration;
        bytes32 salt;
    }
    
    mapping(bytes32 => bool) public executedOrders;
    
    constructor(address _permit3) {
        permit3 = IPermit3(_permit3);
    }
    
    // Multi-sig order functions will be implemented below
}
```

### Step 2: Implement Multi-Signature Witness Verification

```solidity
// Within MultiSigOrderBook.sol

// Generate witness from order data and approver signature
function getMultiSigWitness(
    MultiSigOrder memory order,
    bytes memory approverSignature
) public pure returns (bytes32) {
    return keccak256(abi.encode(
        order.orderId,
        order.maker,
        order.approver,
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut,
        order.expiration,
        approverSignature
    ));
}

// Get witness type string for EIP-712 signature
function getMultiSigWitnessTypeString() public pure returns (string memory) {
    return "MultiSigData data)MultiSigData(uint256 orderId,address maker,address approver,address tokenIn,address tokenOut,uint256 amountIn,uint256 minAmountOut,uint256 expiration,bytes approverSignature)";
}
```

### Step 3: Implement Multi-Signature Order Execution

```solidity
// Within MultiSigOrderBook.sol

function executeMultiSigOrder(
    MultiSigOrder memory order,
    bytes memory approverSignature,
    address maker,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    IPermit3.ChainPermits memory chainPermits,
    bytes32 witness,
    bytes calldata makerSignature
) external {
    // 1. Check order hasn't expired
    require(block.timestamp <= order.expiration, "Order expired");
    
    // 2. Generate order hash
    bytes32 orderHash = keccak256(abi.encode(
        order.orderId,
        order.maker,
        order.approver,
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut,
        order.expiration,
        order.salt
    ));
    
    // 3. Check order hasn't been executed
    require(!executedOrders[orderHash], "Order already executed");
    
    // 4. Verify approver signature (direct ECDSA verification)
    bytes32 approverDigest = keccak256(
        abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            orderHash
        )
    );
    
    address recoveredApprover = _recoverSigner(approverDigest, approverSignature);
    require(recoveredApprover == order.approver, "Invalid approver signature");
    
    // 5. Verify witness matches the multi-sig data
    bytes32 expectedWitness = getMultiSigWitness(order, approverSignature);
    require(witness == expectedWitness, "Invalid witness data");
    
    // 6. Verify maker matches
    require(maker == order.maker, "Invalid maker");
    
    // 7. Verify transfer details
    require(chainPermits.permits.length == 1, "Invalid permit count");
    require(chainPermits.permits[0].token == order.tokenIn, "Invalid token");
    require(chainPermits.permits[0].account == address(this), "Invalid recipient");
    require(chainPermits.permits[0].amountDelta == order.amountIn, "Invalid amount");
    require(chainPermits.permits[0].modeOrExpiration == 0, "Invalid mode");
    
    // 8. Execute permit with witness (includes maker signature verification)
    permit3.permitWitnessTransferFrom(
        maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        getMultiSigWitnessTypeString(),
        makerSignature
    );
    
    // 9. Mark order as executed
    executedOrders[orderHash] = true;
    
    // 10. Execute the trade
    uint256 outputAmount = _executeTrade(
        order.tokenIn,
        order.tokenOut,
        order.amountIn,
        order.minAmountOut
    );
    
    // 11. Send output tokens to maker
    _transferTokens(order.tokenOut, order.maker, outputAmount);
    
    emit MultiSigOrderExecuted(orderHash, order.maker, order.approver, outputAmount);
}

// Helper function to recover signer from signature
function _recoverSigner(bytes32 digest, bytes memory signature) internal pure returns (address) {
    (uint8 v, bytes32 r, bytes32 s) = _splitSignature(signature);
    return ecrecover(digest, v, r, s);
}

function _splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
    require(sig.length == 65, "Invalid signature length");
    assembly {
        r := mload(add(sig, 32))
        s := mload(add(sig, 64))
        v := byte(0, mload(add(sig, 96)))
    }
    if (v < 27) {
        v += 27;
    }
    return (v, r, s);
}

// Implementation of _executeTrade and _transferTokens as in the basic example
// ...

event MultiSigOrderExecuted(
    bytes32 indexed orderHash,
    address indexed maker,
    address indexed approver,
    uint256 outputAmount
);
```

### Step 4: Client-Side Multi-Signature Order Creation and Signing

```javascript
// multi-sig-order-signing.js
const ethers = require('ethers');

async function createMultiSigOrder(
    maker,
    approver,
    tokenIn,
    tokenOut,
    amountIn,
    minAmountOut,
    expiration
) {
    const orderId = Math.floor(Math.random() * 1000000);
    const salt = ethers.utils.randomBytes(32);
    
    return {
        orderId,
        maker,
        approver,
        tokenIn,
        tokenOut,
        amountIn,
        minAmountOut,
        expiration,
        salt
    };
}

async function signOrderAsApprover(signer, order) {
    // Calculate order hash
    const orderHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            [
                'uint256', 'address', 'address', 'address', 
                'address', 'uint256', 'uint256', 'uint256', 'bytes32'
            ],
            [
                order.orderId,
                order.maker,
                order.approver,
                order.tokenIn,
                order.tokenOut,
                order.amountIn,
                order.minAmountOut,
                order.expiration,
                order.salt
            ]
        )
    );
    
    // Sign order hash using standard ETH signature
    return await signer.signMessage(ethers.utils.arrayify(orderHash));
}

async function createAndSignMultiSigOrder(
    makerSigner,
    approverSigner,
    permit3Address,
    orderBookAddress,
    order
) {
    // 1. Get approver signature
    const approverSignature = await signOrderAsApprover(approverSigner, order);
    
    // 2. Create permit data
    const chainPermits = {
        chainId: await makerSigner.getChainId(),
        permits: [{
            modeOrExpiration: 0, // Transfer mode
            token: order.tokenIn,
            account: orderBookAddress,
            amountDelta: order.amountIn
        }]
    };
    
    // 3. Create salt and deadline
    const salt = ethers.utils.randomBytes(32);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 4. Create witness (including approver signature)
    const witness = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            [
                'uint256', 'address', 'address', 'address', 
                'address', 'uint256', 'uint256', 'uint256', 'bytes'
            ],
            [
                order.orderId,
                order.maker,
                order.approver,
                order.tokenIn,
                order.tokenOut,
                order.amountIn,
                order.minAmountOut,
                order.expiration,
                approverSignature
            ]
        )
    );
    
    // 5. Set up EIP-712 domain
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: await makerSigner.getChainId(),
        verifyingContract: permit3Address
    };
    
    // 6. Define types
    const types = {
        PermitWitnessTransferFrom: [
            { name: 'permitted', type: 'ChainPermits' },
            { name: 'spender', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint256' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'data', type: 'MultiSigData' }
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
        ],
        MultiSigData: [
            { name: 'orderId', type: 'uint256' },
            { name: 'maker', type: 'address' },
            { name: 'approver', type: 'address' },
            { name: 'tokenIn', type: 'address' },
            { name: 'tokenOut', type: 'address' },
            { name: 'amountIn', type: 'uint256' },
            { name: 'minAmountOut', type: 'uint256' },
            { name: 'expiration', type: 'uint256' },
            { name: 'approverSignature', type: 'bytes' }
        ]
    };
    
    // 7. Create value to sign
    const value = {
        permitted: chainPermits,
        spender: order.maker,
        salt: salt,
        deadline: deadline,
        timestamp: timestamp,
        data: {
            orderId: order.orderId,
            maker: order.maker,
            approver: order.approver,
            tokenIn: order.tokenIn,
            tokenOut: order.tokenOut,
            amountIn: order.amountIn,
            minAmountOut: order.minAmountOut,
            expiration: order.expiration,
            approverSignature: approverSignature
        }
    };
    
    // 8. Sign the typed data (maker signature)
    const makerSignature = await makerSigner._signTypedData(domain, types, value);
    
    // 9. Return all data needed for execution
    return {
        order,
        approverSignature,
        maker: order.maker,
        salt,
        deadline,
        timestamp,
        chainPermits,
        witness,
        makerSignature
    };
}
```

<a id="summary-and-key-takeaways"></a>
## Summary and Key Takeaways

This example demonstrates how Permit3's witness functionality can be used to create powerful and flexible token permission systems. Key points to remember:

1. **Witness Data is Arbitrary**: You can include any data in the witness, as long as it can be hashed to a bytes32 value
2. **Type Strings are Flexible**: You can define custom EIP-712 type structures for your witness data
3. **Signatures Include Witness**: The user's signature covers both the permit data and the witness data
4. **On-Chain Verification**: You must verify the witness data matches expected values on-chain
5. **Multi-Party Workflows**: Witness data can include signatures from other parties, enabling complex approval flows

Witness functionality enables many advanced DeFi use cases:
- Multi-signature approvals
- Order matching with verification
- Conditional transfers
- Cross-protocol interactions
- Fee specifications
- Metadata inclusion

By leveraging Permit3's witness functionality, you can create more secure and sophisticated token permission systems while maintaining gas efficiency and user experience.

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Examples](/docs/examples/README.md) | [Examples](/docs/examples/README.md) | [Cross-Chain Example](/docs/examples/cross-chain-example.md) |

[🔝 Back to Top](#witness-example-top)