<a id="api-reference-top"></a>
# 🔏 Permit3 API Reference 📘

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > API Reference

This document provides a comprehensive reference for the Permit3 API, including all public interfaces, function signatures, and data structures.

###### Navigation: [Interfaces](#interfaces) | [Data Structures](#data-structures) | [Constants](#constants) | [Errors](#custom-errors) | [Functions](#function-signatures) | [Events](#events) | [EIP-712](#eip-712-domain-separator) | [Type Strings](#type-strings) | [Examples](#usage-examples) | [Modes](#operation-mode-reference) | [Error Reference](#error-reference) | [Nonce Management](#nonce-management-reference) | [Security](#security-considerations)

<a id="interfaces"></a>
## 🔌 Interfaces

### 📄 IPermit3

The main interface for Permit3, extending IPermit and INonceManager.

```solidity
interface IPermit3 is IPermit, INonceManager {
    // Enums, Structs, and Functions defined below
}
```

### 📃 IPermit

Interface for compatibility with contracts that are already using Permit2 for transfers.

```solidity
interface IPermit {
    // Functions for standard permits and transfers that maintain compatibility with Permit2
    // Existing contracts integrated with Permit2 can work with Permit3 without any changes
}
```

### 🧮 INonceManager

Interface for nonce management and signature validation.

```solidity
interface INonceManager {
    // Functions for nonce management
}
```

<a id="data-structures"></a>
## 🧰 Data Structures

### 🔖 Enums

```solidity
enum PermitType {
    Transfer,  // Execute immediate transfer
    Decrease,  // Decrease allowance
    Lock,      // Lock allowance
    Unlock     // Unlock previously locked allowance
}
```

### 📋 Structs

#### ✅ Allowance

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when approval expires
    uint48 timestamp;      // Timestamp when approval was set
}
```

#### 🔄 AllowanceOrTransfer

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;  // Operation mode or expiration time
    address token;            // Token address
    address account;          // Spender or recipient
    uint160 amountDelta;      // Amount change
}
```

#### 🌐 ChainPermits

```solidity
struct ChainPermits {
    uint64 chainId;              // Target chain ID
    AllowanceOrTransfer[] permits; // Operations for this chain
}
```

#### 🌲 Cross-Chain Permit Parameters

Note: In the implementation, cross-chain operations now use separate parameters instead of a struct:
- `ChainPermits calldata permits`: Permit operations for the current chain
- `bytes32[] calldata proof`: Merkle proof array for verification using OpenZeppelin's MerkleProof

<a id="constants"></a>
## Constants

```solidity
bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
    "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)"
);

bytes32 public constant SIGNED_PERMIT3_TYPEHASH = keccak256(
    "Permit3(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot)"
);

// Witness type hash stub for constructing witness permit typehashes
string public constant PERMIT_WITNESS_TYPEHASH_STUB = 
    "PermitWitness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot,";
```

<a id="custom-errors"></a>
## Custom Errors

```solidity
// Standard Errors
// Signature and validation errors
error SignatureExpired(uint48 deadline, uint48 currentTimestamp);
error InvalidSignature(address signer);
error InvalidMerkleProof();
error InvalidParameters();
error WrongChainId(uint256 expected, uint256 provided);
error AllowanceLocked(address owner, address token, address spender);
error InvalidWitnessTypeString(string witnessTypeString);
error NonceAlreadyUsed(address owner, bytes32 salt);
error AllowanceExpired(uint48 deadline);
error InsufficientAllowance(uint256 requestedAmount, uint256 availableAmount);
error EmptyArray();
error ZeroOwner();
error ZeroToken();
error ZeroSpender();
error ZeroFrom();
error ZeroTo();
error ZeroAccount();
error InvalidAmount(uint160 amount);
error InvalidExpiration(uint48 expiration);
```

<a id="function-signatures"></a>
## Function Signatures

### Standard Permit Functions

#### Single Chain Permit

```solidity
function permit(
    address owner,
    bytes32 salt,
    uint48 deadline,
    uint48 timestamp,
    AllowanceOrTransfer[] calldata permits,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `permits`: Array of permit operations to execute
- `signature`: EIP-712 signature authorizing the permits

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Validates signature against owner and permit data
- Processes permits (allowance updates or transfers)

#### Cross-Chain Permit

```solidity
function permit(
    address owner,
    bytes32 salt,
    uint48 deadline,
    uint48 timestamp,
    ChainPermits calldata permits,
    bytes32[] calldata proof,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `permits`: Permit operations for the current chain
- `proof`: Merkle proof array for verification
- `signature`: EIP-712 signature authorizing the batch

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Verifies the merkle proof using OpenZeppelin's MerkleProof library
- Calculates the merkle root from the proof components
- Validates signature against owner and unbalanced root
- Processes permits for current chain only

#### Direct Permit (ERC-7702 Integration)

```solidity
function permit(
    AllowanceOrTransfer[] memory permits
) external;
```

**Parameters:**
- `permits`: Array of permit operations to execute on current chain

**Behavior:**
- Uses `msg.sender` as the token owner (no signature verification)
- Automatically uses current `block.chainid` (no need to specify)
- Processes permits directly (allowance updates or transfers)
- Designed for ERC-7702 delegatecall usage where caller authority is verified via authorization

**Use Cases:**
- ERC-7702 Token Approver integration
- Direct permit execution without signatures
- Direct permit operations for trusted callers
- Single-chain operations where caller has direct authority

### Witness Permit Functions

#### Single Chain Witness Permit

```solidity
function permitWitness(
    address owner,
    bytes32 salt,
    uint48 deadline,
    uint48 timestamp,
    AllowanceOrTransfer[] calldata permits,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `permits`: Array of permit operations to execute
- `witness`: Additional data to include in signature verification
- `witnessTypeString`: EIP-712 type definition for witness data
- `signature`: EIP-712 signature authorizing the permits

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Validates witness type string format
- Constructs type hash with witness data
- Validates signature against owner, permit data, and witness
- Processes permits (allowance updates or transfers)

#### Cross-Chain Witness Permit

```solidity
function permitWitness(
    address owner,
    bytes32 salt,
    uint48 deadline,
    uint48 timestamp,
    ChainPermits calldata permits,
    bytes32[] calldata proof,
    bytes32 witness,
    string calldata witnessTypeString,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `permits`: Permit operations for the current chain
- `proof`: Merkle proof array for verification
- `witness`: Additional data to include in signature verification
- `witnessTypeString`: EIP-712 type definition for witness data
- `signature`: EIP-712 signature authorizing the batch

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Validates witness type string format
- Verifies the merkle proof using OpenZeppelin's MerkleProof library
- Calculates the merkle root from the proof components
- Constructs type hash with witness data
- Validates signature against owner, unbalanced root, and witness
- Processes permits for current chain only

### Witness TypeHash Helper Functions

```solidity
function PERMIT_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
```

**Returns:** The stub string for witness permit typehash construction

### Permit2 Compatibility Functions

#### Token Approval

```solidity
function approve(
    address token,
    address spender,
    uint160 amount,
    uint48 expiration
) external;
```

**Parameters:**
- `token`: ERC20 token address
- `spender`: Approved spender address
- `amount`: Approval amount
- `expiration`: Approval expiration timestamp

**Behavior:**
- Updates allowance for token/spender
- Sets expiration timestamp
- Emits Permit event

#### Single Token Transfer

```solidity
function transferFrom(
    address from,
    address to,
    uint160 amount,
    address token
) external;
```

**Parameters:**
- `from`: Token owner address
- `to`: Recipient address
- `amount`: Transfer amount
- `token`: ERC20 token address

**Behavior:**
- Checks allowance is sufficient
- Decreases allowance
- Transfers tokens from owner to recipient

#### Batch Token Transfer

```solidity
function transferFrom(
    AllowanceTransferDetails[] calldata transfers
) external;
```

**Parameters:**
- `transfers`: Array of transfer details

**Behavior:**
- Processes multiple transfers in one transaction
- Checks all allowances
- Decreases allowances
- Transfers tokens for each entry

#### Allowance Query

```solidity
function allowance(
    address user,
    address token,
    address spender
) external view returns (uint160 amount, uint48 expiration, uint48 timestamp);
```

**Parameters:**
- `user`: Token owner address
- `token`: ERC20 token address
- `spender`: Approved spender address

**Returns:**
- `amount`: Current approved amount
- `expiration`: Approval expiration timestamp
- `timestamp`: Current timestamp value for the allowance

#### Lockdown

```solidity
function lockdown(
    TokenSpenderPair[] calldata approvals
) external;
```

**Parameters:**
- `approvals`: Array of token/spender pairs to lock

**Behavior:**
- Sets allowance to 0 for all token/spender pairs
- Sets locked state
- Records current timestamp
- Emits Permit events

### NonceManager Functions

#### Nonce Invalidation (Direct)

```solidity
function invalidateNonces(
    bytes32[] calldata salts
) external;
```

**Parameters:**
- `salts`: Array of salt values to invalidate

**Behavior:**
- Mark the nonces as used for msg.sender
- Prevents signatures with those salts from being used

#### Nonce Invalidation (With Signature)

```solidity
function invalidateNonces(
    address owner,
    uint48 deadline,
    bytes32[] calldata salts,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Owner address
- `deadline`: Signature expiration timestamp
- `salts`: Array of salt values to invalidate
- `signature`: EIP-712 signature authorizing the invalidation

**Behavior:**
- Verify signature authorization
- Mark the nonces as used for the specified owner
- Prevents signatures with those salts from being used

#### Cross-Chain Nonce Invalidation

```solidity
function invalidateNonces(
    address owner,
    uint48 deadline,
    NoncesToInvalidate memory invalidations,
    bytes32[] memory proof,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Owner address
- `deadline`: Signature expiration timestamp
- `invalidations`: Current chain invalidation data
- `proof`: Merkle proof array for verification
- `signature`: EIP-712 signature authorizing the invalidation

**Behavior:**
- Verify merkle proof and signature authorization
- Mark the nonces as used for the specified owner on current chain
- Prevents signatures with those salts from being used

#### Hash Nonces Function

```solidity
function hashNoncesToInvalidate(
    NoncesToInvalidate memory invalidations
) external pure returns (bytes32);
```

**Parameters:**
- `invalidations`: Nonce invalidation parameters

**Returns:** EIP-712 compatible hash

#### Domain Separator

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32);
```

**Returns:** The EIP-712 domain separator for this contract

#### Nonce Query

```solidity
function isNonceUsed(
    address owner,
    bytes32 salt
) external view returns (bool);
```

**Parameters:**
- `owner`: Owner address
- `salt`: Salt value to check

**Returns:** True if the nonce has been used, false otherwise

<a id="events"></a>
## Events

```solidity
event Approval(
    address indexed owner,
    address indexed token,
    address indexed spender,
    uint160 amount,
    uint48 expiration
);

event Lockdown(
    address indexed owner,
    address token,
    address spender
);

event NonceInvalidated(
    address indexed owner,
    bytes32 indexed salt
);

event Permit(
    address indexed owner,
    address indexed token,
    address indexed spender,
    uint160 amount,
    uint48 expiration,
    uint48 timestamp
);
```

<a id="eip-712-domain-separator"></a>
## EIP-712 Domain Separator

Permit3 uses EIP-712 domain separation with the following parameters:

```javascript
const domain = {
    name: 'Permit3',
    version: '1',
    chainId: 1,  // ALWAYS 1 (CROSS_CHAIN_ID) for cross-chain compatibility
    verifyingContract: permit3Address
};
```

<a id="type-strings"></a>
## Type Strings

### Standard Permit

```
Permit3(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot)
ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)
AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)
```

### Witness Permit

```
// Base type stubs (incomplete)
PermitWitness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot,
PermitWitness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot,

// Completed by custom witness type string, for example:
bytes32 witnessData)

// Or for more complex witness data:
OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration)
```

<a id="usage-examples"></a>
## Usage Examples

### Basic Permit

```solidity
// Create and sign permit
bytes32 salt = generateSalt();
uint48 deadline = uint48(block.timestamp + 1 hours);
uint48 timestamp = uint48(block.timestamp);

IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
permits[0] = IPermit3.AllowanceOrTransfer({
    modeOrExpiration: 0, // Transfer mode
    token: USDC,
    account: recipient,
    amountDelta: 1000e6 // 1000 USDC
});

bytes memory signature = signPermit(owner, salt, deadline, timestamp, permits);

// Execute permit
permit3.permit(
    owner,
    salt,
    deadline,
    timestamp,
    permits,
    signature
);
```

### Cross-Chain Permit

```solidity
// Create permits for each chain
IPermit3.ChainPermits memory ethPermits = IPermit3.ChainPermits({
    chainId: 1, // Ethereum
    permits: [
        IPermit3.AllowanceOrTransfer({
            modeOrExpiration: futureTimestamp,
            token: USDC_ETH,
            account: DEX_ETH,
            amountDelta: 1000e6
        })
    ]
});

IPermit3.ChainPermits memory arbPermits = IPermit3.ChainPermits({
    chainId: 42161, // Arbitrum
    permits: [
        IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 1, // Decrease mode
            token: USDC_ARB,
            account: DEX_ARB,
            amountDelta: 500e6
        })
    ]
});

// Generate leaf hashes for each chain
bytes32 ethLeaf = permit3.hashChainPermits(ethPermits);
bytes32 arbLeaf = permit3.hashChainPermits(arbPermits);

// Build merkle tree and get root
bytes32[] memory leaves = new bytes32[](2);
leaves[0] = ethLeaf;
leaves[1] = arbLeaf;

// Calculate merkle root (in production use a library)
bytes32 merkleRoot = buildMerkleRoot(leaves);
bytes memory signature = signPermit3(owner, salt, deadline, timestamp, merkleRoot);

// Generate merkle proofs
bytes32[] memory ethProofNodes = new bytes32[](1);
ethProofNodes[0] = arbLeaf; // Sibling for Ethereum

bytes32[] memory arbProofNodes = new bytes32[](1);
arbProofNodes[0] = ethLeaf; // Sibling for Arbitrum

// Execute on Ethereum chain
permit3.permit(owner, salt, deadline, timestamp, ethPermits, ethProofNodes, signature);

// Execute on Arbitrum chain
permit3.permit(owner, salt, deadline, timestamp, arbPermits, arbProofNodes, signature);
```

### Witness Permit

```solidity
// Create witness data
bytes32 witness = keccak256(abi.encode(
    orderId,
    price,
    expiration
));
string memory witnessTypeString = "OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration)";

// Sign witness permit
bytes memory signature = signWitnessPermit(
    owner,
    salt,
    deadline,
    timestamp,
    chainPermits,
    witness,
    witnessTypeString
);

// Execute witness permit
permit3.permitWitness(
    owner,
    salt,
    deadline,
    timestamp,
    permits,
    witness,
    witnessTypeString,
    signature
);
```

<a id="operation-mode-reference"></a>
## Operation Mode Reference

| Mode Value | Operation Type | Description |
|------------|----------------|-------------|
| 0 | Transfer | Immediate token transfer to recipient |
| 1 | Decrease | Reduce existing allowance |
| 2 | Lock | Lock allowance for security |
| 3 | Unlock | Unlock previously locked allowance |
| > 3 | Increase | Increase allowance with expiration timestamp |

<a id="error-reference"></a>
## Error Reference

| Error | Description | Mitigation |
|-------|-------------|------------|
| `SignatureExpired(deadline, currentTimestamp)` | Deadline has passed | Use future deadlines, check system time |
| `InvalidSignature(signer)` | Signature verification failed | Verify signer, domain params, and hash construction |
| `WrongChainId(expected, provided)` | Chain ID mismatch | Ensure chain ID in permit matches current chain |
| `AllowanceLocked(owner, token, spender)` | Account is in locked state | Unlock with newer timestamp before operations |
| `InvalidWitnessTypeString(witnessTypeString)` | Witness type string is malformed | Ensure type string is valid EIP-712 format with closing parenthesis |
| `NonceAlreadyUsed(owner, salt)` | Salt has been used | Generate unique salts for each signature |
| `EmptyArray()` | Empty array provided | Ensure arrays contain at least one element |
| `ZeroOwner()` | Owner address is zero | Validate addresses before function calls |
| `AllowanceExpired(deadline)` | Allowance has expired | Check expiration before operations |
| `InsufficientAllowance(requested, available)` | Not enough allowance | Check current allowance before transfers |

<a id="nonce-management-reference"></a>
## Nonce Management Reference

Permit3 uses a salt-based nonce system:

- Each user has a mapping from salt to usage status
- Salts are bytes32 values that must be unique per signature
- Once a salt is used, it cannot be reused
- Users can pre-invalidate salts to prevent future use

This approach:
- Enables concurrent operations (different salts)
- Prevents replay attacks
- Provides flexible nonce management
- Supports cross-chain operations with unique salts

<a id="security-considerations"></a>
## Security Considerations

- **Signature Expiration**: Always set reasonable deadlines
- **Nonce Management**: Use unique salts for each signature
- **Chain ID Validation**: Verify chain IDs to prevent cross-chain replay
- **Witness Data Verification**: Validate witness data before taking action
- **Account Locking**: Understand implications of locked state
- **Timestamp Ordering**: Be aware of timestamp-based operation ordering
- **Allowance Management**: Monitor allowance changes across chains

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [API Reference](/docs/api/README.md) | [API Reference](/docs/api/README.md) | [Data Structures](/docs/api/data-structures.md) |