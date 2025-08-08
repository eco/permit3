<a id="interfaces-top"></a>
# 🔏 Permit3 Interfaces 🔌

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > Interfaces

This document provides a comprehensive reference of all interfaces in the Permit3 system.

###### Navigation: [IPermit3](#ipermit3) | [IPermit](#ipermit) | [INonceManager](#inoncemanager) | [Merkle Tree Methodology](#merkle-tree-methodology) | [Inheritance Diagram](#interface-inheritance-diagram) | [Implementation Contracts](#implementation-contracts)

<a id="ipermit3"></a>
## 📄 IPermit3

The main interface for Permit3, combining IPermit and INonceManager functionality plus additional features.

```solidity
interface IPermit3 is IPermit, INonceManager {
    // Core structs and definitions
    struct ChainPermits {
        uint64 chainId;
        AllowanceOrTransfer[] permits;
    }
    
    struct AllowanceOrTransfer {
        uint48 modeOrExpiration;
        address token;
        address account;
        uint160 amountDelta;
    }
    
    struct UnhingedPermitProof {
        ChainPermits permits;
        bytes32[] unhingedProof;
    }
    
    enum PermitType {
        Transfer,
        Decrease,
        Lock,
        Unlock
    }
    
    // Standard permit functions
    function permit(
        address owner,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp,
        AllowanceOrTransfer[] calldata permits,
        bytes calldata signature
    ) external;
    
    function permit(
        address owner,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp,
        UnhingedPermitProof calldata proof,
        bytes calldata signature
    ) external;
    
    // Direct permit (ERC-7702 integration)
    function permit(
        AllowanceOrTransfer[] memory permits
    ) external;
    
    // Witness functions
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
    
    function permitWitness(
        address owner,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp,
        UnhingedPermitProof calldata proof,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;
    
    // Allowance management
    function allowance(address user, address token, address spender) 
        external view returns (uint160 amount, uint48 expiration, uint48 timestamp);
        
    // Hash functions
    function hashChainPermits(ChainPermits memory chainPermits) external pure returns (bytes32);
    
    // Type hash functions
    function PERMIT_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
}
```

<a id="ipermit"></a>
## 📃 IPermit

Interface providing compatibility with Permit2 functions.

```solidity
interface IPermit {
    // Core structs
    struct TokenSpenderPair {
        address token;
        address spender;
    }
    
    struct AllowanceTransferDetails {
        address from;
        address to;
        uint160 amount;
        address token;
    }
    
    // Standard Permit2-compatible functions
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;
    
    // Transfer functions
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;
    
    function transferFrom(
        AllowanceTransferDetails[] calldata transferDetails
    ) external;
    
    // Lockdown function
    function lockdown(TokenSpenderPair[] calldata approvals) external;
}
```

<a id="inoncemanager"></a>
## 🧮 INonceManager

Interface for managing nonces (salts) to prevent replay attacks.

```solidity
interface INonceManager is IPermit {
    // Core structs
    struct NoncesToInvalidate {
        uint64 chainId;
        bytes32[] salts;
    }
    
    struct UnhingedCancelPermitProof {
        NoncesToInvalidate invalidations;
        bytes32[] unhingedProof;
    }
    
    // Core functions
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function isNonceUsed(address owner, bytes32 salt) external view returns (bool);
    
    // Nonce operations
    function invalidateNonces(bytes32[] calldata salts) external;
    
    function invalidateNonces(
        address owner,
        uint48 deadline,
        bytes32[] calldata salts,
        bytes calldata signature
    ) external;
    
    function invalidateNonces(
        address owner,
        uint48 deadline,
        UnhingedCancelPermitProof memory proof,
        bytes calldata signature
    ) external;
    
    // Hash functions
    function hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) external pure returns (bytes32);
}
```

<a id="merkle-tree-methodology"></a>
## 🌲 Unhinged Merkle Tree Methodology

The Unhinged Merkle tree methodology uses OpenZeppelin's MerkleProof library for verification.

```solidity
// Uses OpenZeppelin's MerkleProof.processProof() directly
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Standard merkle proof verification
function verify(
    bytes32[] calldata proof,
    bytes32 root,
    bytes32 leaf
) internal pure returns (bool) {
    return MerkleProof.processProof(proof, leaf) == root;
}
```

<a id="interface-inheritance-diagram"></a>
## 📊 Interface Inheritance Diagram

```
┌─────────────────┐
│ INonceManager   │
├─────────────────┤
│ invalidateNonces│
│ isNonceUsed     │
└─────────┬───────┘
          │
          │
┌─────────▼───────┐     ┌─────────────────────┐
│ IPermit         │     │ MerkleProof (OZ)    │
├─────────────────┤     ├─────────────────────┤
│ approve         │     │ verify              │
│ permit          │     │ hashLink            │
│ transferFrom    │     │ createOptimizedProof│
│ lockdown        │     │ extractCounts       │
└─────────┬───────┘     └─────────────────────┘
          │                       ▲
          │                       │
┌─────────▼───────┐    library    │
│ IPermit3        ├───────────────┘
├─────────────────┤
│ permitWitness   │
│ allowance       │
│ TYPEHASH funcs  │
└─────────────────┘
```

This diagram shows the inheritance relationship between interfaces in the Permit3 system.

<a id="implementation-contracts"></a>
## 📁 Implementation Contracts

The main contracts implementing these interfaces are:

- 📄 **Permit3.sol**: Implements IPermit3, providing the complete functionality
- 🔢 **NonceManager.sol**: Implements INonceManager for replay protection
- 📃 **PermitBase.sol**: Implements IPermit for compatibility with contracts that are already using Permit2 for transfers
- 🌲 **OpenZeppelin MerkleProof**: Standard library used for Unhinged Merkle tree methodology

These interfaces provide a flexible and extensible foundation for the Permit3 system, allowing for future upgrades and extensions while maintaining compatibility with existing systems.