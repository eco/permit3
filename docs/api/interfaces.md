<a id="interfaces-top"></a>
# Permit3 Interfaces


<a id="ipermit3"></a>
## IPermit3

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
    
    // Note: In the implementation, cross-chain operations use separate parameters:
    // - ChainPermits calldata permits: Permit operations for the current chain
    // - bytes32[] calldata proof: Merkle proof array for verification
    
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
        ChainPermits calldata permits,
        bytes32[] calldata proof,
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
        ChainPermits calldata permits,
        bytes32[] calldata proof,
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
## IPermit

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
## INonceManager

Interface for managing nonces (salts) to prevent replay attacks.

```solidity
interface INonceManager is IPermit {
    // Core structs
    struct NoncesToInvalidate {
        uint64 chainId;
        bytes32[] salts;
    }
    
    // Note: Cross-chain nonce invalidation uses separate parameters:
    // - NoncesToInvalidate calldata invalidations: Current chain invalidation data
    // - bytes32[] calldata proof: Merkle proof array for verification
    
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
        NoncesToInvalidate memory invalidations,
        bytes32[] memory proof,
        bytes calldata signature
    ) external;
    
    // Hash functions
    function hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) external pure returns (bytes32);
}
```

<a id="imultitokenpermit"></a>
## IMultiTokenPermit

Interface for multi-token support including NFTs (ERC721) and semi-fungible tokens (ERC1155).

```solidity
interface IMultiTokenPermit {
    // Errors
    error InvalidArrayLength();
    
    // Token type enum
    enum TokenStandard {
        ERC20,   // Standard fungible tokens
        ERC721,  // Non-fungible tokens (NFTs)
        ERC1155  // Semi-fungible tokens
    }
    
    // Data structures
    struct MultiTokenTransfer {
        address from;
        address to;
        address token;
        uint256 tokenId;    // 0 for ERC20, specific ID for NFT/ERC1155
        uint160 amount;     // 1 for ERC721, variable for others
    }
    
    struct ERC721TransferDetails {
        address from;
        address to;
        uint256 tokenId;
        address token;
    }
    
    struct ERC1155BatchTransferDetails {
        address from;
        address to;
        uint256[] tokenIds;
        uint256[] amounts;
        address token;
    }
    
    struct TokenTypeTransfer {
        TokenStandard tokenType;
        MultiTokenTransfer transfer;
    }
    
    // Functions
    
    // Query multi-token allowance
    function allowance(
        address owner,
        address token,
        address spender,
        uint256 tokenId  // 0 for ERC20, type(uint256).max for collection wildcard
    ) external view returns (uint160 amount, uint48 expiration, uint48 timestamp);
    
    // Approve tokens with ID support
    function approve(
        address token,
        address spender,
        uint256 tokenId,  // 0 for ERC20, specific ID or max for wildcard
        uint160 amount,   // Ignored for ERC721
        uint48 expiration
    ) external;
    
    // ERC721 transfer
    function transferFrom(
        address from,
        address to,
        address token,
        uint256 tokenId
    ) external;
    
    // ERC1155 transfer
    function transferFrom(
        address from,
        address to,
        address token,
        uint256 tokenId,
        uint160 amount
    ) external;
    
    // Batch operations
    function transferFrom(
        ERC721TransferDetails[] calldata transfers
    ) external;
    
    function transferFrom(
        MultiTokenTransfer[] calldata transfers
    ) external;
    
    function batchTransferFrom(
        ERC1155BatchTransferDetails calldata transfer
    ) external;
    
    function batchTransferFrom(
        TokenTypeTransfer[] calldata transfers
    ) external;
}
```

### Key Features

- **Dual-Allowance System**: Check per-token allowance first, fall back to collection-wide
- **TokenId Encoding**: Encodes tokenId as address using `keccak256(token || tokenId)`
- **Batch Operations**: Efficient multi-token transfers in single transaction
- **Token Type Support**: Unified interface for ERC20, ERC721, and ERC1155

<a id="merkle-tree-methodology"></a>
## Unbalanced Merkle Tree Methodology

The Unbalanced Merkle tree methodology uses OpenZeppelin's MerkleProof library for verification.

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
## Interface Inheritance Diagram

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
└────────┬────────┘
         │
         │
┌────────▼──────────┐
│ IMultiTokenPermit │
├───────────────────┤
│ ERC721 support    │
│ ERC1155 support   │
│ Batch operations  │
│ Dual-allowance    │
└───────────────────┘
```

This diagram shows the inheritance relationship between interfaces in the Permit3 system.

<a id="implementation-contracts"></a>
## Implementation Contracts

The main contracts implementing these interfaces are:

- **Permit3.sol**: Implements IPermit3, providing the complete functionality
- **NonceManager.sol**: Implements INonceManager for replay protection
- **PermitBase.sol**: Implements IPermit for compatibility with contracts that are already using Permit2 for transfers
- **OpenZeppelin MerkleProof**: Standard library used for Unbalanced Merkle tree methodology

These interfaces provide a flexible and extensible foundation for the Permit3 system, allowing for future upgrades and extensions while maintaining compatibility with existing systems.