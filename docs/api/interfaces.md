<a id="interfaces-top"></a>
# 🔏 Permit3 Interfaces 🔌

🧭 [Home](/docs/README.md) > [API Reference](/docs/api/README.md) > Interfaces

This document provides a comprehensive reference of all interfaces in the Permit3 system.

###### Navigation: [IPermit3](#ipermit3) | [IPermit](#ipermit) | [INonceManager](#inoncemanager) | [IUnhingedMerkleTree](#iunhingedmerkletree) | [Inheritance Diagram](#interface-inheritance-diagram) | [Implementation Contracts](#implementation-contracts)

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
        UnhingedPermitProof calldata unhingedPermitProof,
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
        UnhingedPermitProof calldata unhingedPermitProof,
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
    function PERMIT_TRANSFER_FROM_TYPEHASH() external pure returns (bytes32);
    function PERMIT_BATCH_TRANSFER_FROM_TYPEHASH() external pure returns (bytes32);
    function PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB() external pure returns (string memory);
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
    
    function permit(
        address owner,
        address token,
        address spender,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        bytes calldata signature
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
interface INonceManager {
    // Core structs
    struct NoncesToInvalidate {
        bytes32[] salts;
    }
    
    // Nonce operations
    function invalidateNonces(bytes32[] calldata salts) external;
    function isNonceUsed(address owner, bytes32 salt) external view returns (bool);
}
```

<a id="iunhingedmerkletree"></a>
## 🌲 IUnhingedMerkleTree

Interface for the UnhingedMerkleTree library providing merkle proof functionality.

```solidity
interface IUnhingedMerkleTree {
    // Error definitions
    error InvalidMerkleProof();
    error InvalidParameters();
}

// Library functions (not part of interface, but available)
library UnhingedMerkleTree {
    function verify(
        bytes32[] calldata unhingedProof,
        bytes32 unhingedRoot,
        bytes32 leaf
    ) internal pure returns (bool);
    
    function calculateRoot(
        bytes32[] calldata unhingedProof,
        bytes32 leaf
    ) internal pure returns (bytes32);
    
    function verifyProof(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) internal pure returns (bool);
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
│ IPermit         │     │ IUnhingedMerkleTree │
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
- 🌲 **UnhingedMerkleTree.sol**: Library implementing IUnhingedMerkleTree functionality

These interfaces provide a flexible and extensible foundation for the Permit3 system, allowing for future upgrades and extensions while maintaining compatibility with existing systems.