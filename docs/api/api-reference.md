# Permit3 API Reference

This document provides a comprehensive reference for the Permit3 API, including all public interfaces, function signatures, and data structures.

## Interfaces

### IPermit3

The main interface for Permit3, extending IPermit and INonceManager.

```solidity
interface IPermit3 is IPermit, INonceManager {
    // Enums, Structs, and Functions defined below
}
```

### IPermit

Interface for backwards compatibility with Permit2.

```solidity
interface IPermit {
    // Functions for standard permits and transfers
}
```

### INonceManager

Interface for nonce management and signature validation.

```solidity
interface INonceManager {
    // Functions for nonce management
}
```

## Data Structures

### Enums

```solidity
enum PermitType {
    Transfer,  // Execute immediate transfer
    Decrease,  // Decrease allowance
    Lock,      // Lock allowance
    Unlock     // Unlock previously locked allowance
}
```

### Structs

#### Allowance

```solidity
struct Allowance {
    uint160 amount;        // Approved amount
    uint48 expiration;     // Timestamp when approval expires
    uint48 timestamp;      // Timestamp when approval was set
}
```

#### AllowanceOrTransfer

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;  // Operation mode or expiration time
    address token;            // Token address
    address account;          // Spender or recipient
    uint160 amountDelta;      // Amount change
}
```

#### ChainPermits

```solidity
struct ChainPermits {
    uint256 chainId;             // Target chain ID
    AllowanceOrTransfer[] permits; // Operations for this chain
}
```

#### UnhingedPermitProof

```solidity
struct UnhingedPermitProof {
    ChainPermits permits;     // Permit operations for the current chain
    IUnhingedMerkleTree.UnhingedProof unhingedProof; // Unhinged Merkle Tree proof structure
}
```

## Constants

```solidity
bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
    "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)"
);

bytes32 public constant SIGNED_PERMIT3_TYPEHASH = keccak256(
    "SignedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)"
);

bytes32 public constant SIGNED_UNHINGED_PERMIT3_TYPEHASH = keccak256(
    "SignedUnhingedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)"
);

// Witness type hash stubs
string private constant _PERMIT_WITNESS_TYPEHASH_STUB = 
    "PermitWitnessTransferFrom(ChainPermits permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,";
    
string private constant _PERMIT_BATCH_WITNESS_TYPEHASH_STUB = 
    "PermitBatchWitnessTransferFrom(ChainPermits[] permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,";
    
string private constant _PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB =
    "PermitUnhingedWitnessTransferFrom(bytes32 unhingedRoot,address owner,bytes32 salt,uint256 deadline,uint48 timestamp,";
```

## Custom Errors

```solidity
// Standard Errors
error SignatureExpired();
error InvalidSignature();
error WrongChainId(uint256 expected, uint256 actual);
error AllowanceLocked();

// Witness-specific Errors
error InvalidWitnessTypeString();
```

## Function Signatures

### Standard Permit Functions

#### Single Chain Permit

```solidity
function permit(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    ChainPermits memory chain,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `chain`: Chain-specific permit data
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
    uint256 deadline,
    uint48 timestamp,
    UnhingedPermitProof calldata proof,
    bytes calldata signature
) external;
```

**Parameters:**
- `owner`: Token owner address
- `salt`: Unique salt for replay protection
- `deadline`: Signature expiration timestamp
- `timestamp`: Timestamp of the permit
- `proof`: Cross-chain proof data using UnhingedMerkleTree
- `signature`: EIP-712 signature authorizing the batch

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Verifies the UnhingedProof structure
- Calculates the unhinged root from the proof components
- Validates signature against owner and unhinged root
- Processes permits for current chain only

### Witness Permit Functions

#### Single Chain Witness Permit

```solidity
function permitWitnessTransferFrom(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    ChainPermits memory chain,
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
- `chain`: Chain-specific permit data
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
function permitWitnessTransferFrom(
    address owner,
    bytes32 salt,
    uint256 deadline,
    uint48 timestamp,
    UnhingedPermitProof calldata proof,
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
- `proof`: Cross-chain proof data using UnhingedMerkleTree
- `witness`: Additional data to include in signature verification
- `witnessTypeString`: EIP-712 type definition for witness data
- `signature`: EIP-712 signature authorizing the batch

**Behavior:**
- Verifies signature has not expired
- Checks chain ID matches current chain
- Validates witness type string format
- Verifies the UnhingedProof structure
- Calculates the unhinged root from the proof components
- Constructs type hash with witness data
- Validates signature against owner, unhinged root, and witness
- Processes permits for current chain only

### Witness TypeHash Helper Functions

```solidity
function PERMIT_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
```

**Returns:** The stub string for witness permit typehash

```solidity
function PERMIT_BATCH_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
```

**Returns:** The stub string for batch witness permit typehash

```solidity
function PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
```

**Returns:** The stub string for unhinged witness permit typehash

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
) external view returns (uint160 amount, uint48 expiration, uint48 nonce);
```

**Parameters:**
- `user`: Token owner address
- `token`: ERC20 token address
- `spender`: Approved spender address

**Returns:**
- `amount`: Current approved amount
- `expiration`: Approval expiration timestamp
- `nonce`: Current nonce value

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

#### Nonce Invalidation

```solidity
function invalidateNonces(
    address owner,
    bytes32 salt
) external;
```

**Parameters:**
- `owner`: Owner address
- `salt`: Salt to invalidate

**Behavior:**
- Mark the nonce as used
- Prevents signatures with that salt from being used

#### Nonce Validation

```solidity
function nonceBitmap(
    address owner,
    uint256 wordPos
) external view returns (uint256);
```

**Parameters:**
- `owner`: Owner address
- `wordPos`: Word position in bitmap

**Returns:** The nonce bitmap at the specified position

## Events

```solidity
event NonceInvalidation(
    address indexed owner,
    bytes32 indexed salt
);

event NonceUsed(
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

## EIP-712 Domain Separator

Permit3 uses EIP-712 domain separation with the following parameters:

```javascript
const domain = {
    name: 'Permit3',
    version: '1',
    chainId: chainId,
    verifyingContract: permit3Address
};
```

## Type Strings

### Standard Permit

```
SignedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)
SignedUnhingedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)
ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)
AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)
```

### Witness Permit

```
// Base type stubs (incomplete)
PermitWitnessTransferFrom(ChainPermits permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,
PermitBatchWitnessTransferFrom(ChainPermits[] permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,
PermitUnhingedWitnessTransferFrom(bytes32 unhingedRoot,address owner,bytes32 salt,uint256 deadline,uint48 timestamp,

// Completed by custom witness type string, for example:
bytes32 witnessData)

// Or for more complex witness data:
OrderData data)OrderData(uint256 orderId,uint256 price,uint256 expiration)
```

## Usage Examples

### Basic Permit

```solidity
// Create and sign permit
bytes32 salt = generateSalt();
uint256 deadline = block.timestamp + 1 hours;
uint48 timestamp = uint48(block.timestamp);

IPermit3.ChainPermits memory chainPermits = IPermit3.ChainPermits({
    chainId: block.chainid,
    permits: [
        IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0, // Transfer mode
            token: USDC,
            account: recipient,
            amountDelta: 1000e6 // 1000 USDC
        })
    ]
});

bytes memory signature = signPermit(owner, salt, deadline, timestamp, chainPermits);

// Execute permit
permit3.permit(
    owner,
    salt,
    deadline,
    timestamp,
    chainPermits,
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

// Generate roots for each chain
bytes32 ethRoot = permit3.hashChainPermits(ethPermits);
bytes32 arbRoot = permit3.hashChainPermits(arbPermits);

// Create unhinged root and sign
bytes32 unhingedRoot = UnhingedMerkleTree.hashLink(ethRoot, arbRoot);
bytes memory signature = signPermit3(owner, salt, deadline, timestamp, unhingedRoot);

// Execute on Ethereum chain
IPermit3.UnhingedPermitProof memory ethProof = IPermit3.UnhingedPermitProof({
    permits: ethPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        bytes32(0), // No prehash for first chain
        new bytes32[](0), // No subtree proof
        [arbRoot] // Following chain root
    )
});

permit3.permit(owner, salt, deadline, timestamp, ethProof, signature);

// Execute on Arbitrum chain
IPermit3.UnhingedPermitProof memory arbProof = IPermit3.UnhingedPermitProof({
    permits: arbPermits,
    unhingedProof: UnhingedMerkleTree.createOptimizedProof(
        ethRoot, // Prehash is the Ethereum root
        new bytes32[](0), // No subtree proof
        new bytes32[](0) // No following hashes
    )
});

permit3.permit(owner, salt, deadline, timestamp, arbProof, signature);
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
```

## Operation Mode Reference

| Mode Value | Operation Type | Description |
|------------|----------------|-------------|
| 0 | Transfer | Immediate token transfer to recipient |
| 1 | Decrease | Reduce existing allowance |
| 2 | Lock | Lock allowance for security |
| 3 | Unlock | Unlock previously locked allowance |
| > 3 | Increase | Increase allowance with expiration timestamp |

## Error Reference

| Error | Description | Mitigation |
|-------|-------------|------------|
| `SignatureExpired()` | Deadline has passed | Use future deadlines, check system time |
| `InvalidSignature()` | Signature verification failed | Verify signer, domain params, and hash construction |
| `WrongChainId(expected, actual)` | Chain ID mismatch | Ensure chain ID in permit matches current chain |
| `AllowanceLocked()` | Account is in locked state | Unlock with newer timestamp before operations |
| `InvalidWitnessTypeString()` | Witness type string is malformed | Ensure type string is valid EIP-712 format with closing parenthesis |

## Nonce Management Reference

Permit3 uses a bitmap-based nonce system:

- Each user has a mapping of 256-bit words
- Each word can track 256 different nonces
- Nonces are invalidated by setting bits in the bitmap
- Salt values determine which bit to set

This approach:
- Enables concurrent operations (different salts)
- Prevents replay attacks
- Optimizes gas usage for nonce tracking
- Supports cross-chain nonce management

## Security Considerations

- **Signature Expiration**: Always set reasonable deadlines
- **Nonce Management**: Use unique salts for each signature
- **Chain ID Validation**: Verify chain IDs to prevent cross-chain replay
- **Witness Data Verification**: Validate witness data before taking action
- **Account Locking**: Understand implications of locked state
- **Timestamp Ordering**: Be aware of timestamp-based operation ordering
- **Allowance Management**: Monitor allowance changes across chains