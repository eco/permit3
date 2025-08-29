<a id="multi-token-top"></a>
# 🎨 Multi-Token Support (NFTs & Semi-Fungible Tokens) 🖼️

🧭 [Home](/docs/README.md) > [Concepts](/docs/concepts/README.md) > Multi-Token Support

This document explains Permit3's comprehensive support for multiple token standards including ERC20, ERC721 (NFTs), and ERC1155 (semi-fungible tokens).

###### Navigation: [Overview](#overview) | [Token Standards](#supported-token-standards) | [Dual-Allowance System](#dual-allowance-system) | [TokenId Encoding](#tokenid-encoding-as-address) | [Batch Operations](#batch-operations) | [Use Cases](#use-cases)

<a id="overview"></a>
## 🌟 Overview

Permit3's MultiToken functionality extends the protocol beyond ERC20 tokens to provide unified permission management for:
- **ERC721 NFTs**: Unique, non-fungible tokens with individual token IDs
- **ERC1155 Semi-Fungible Tokens**: Tokens that combine fungible and non-fungible properties
- **ERC20 Tokens**: Standard fungible tokens (already supported in base Permit3)

This unified approach enables developers to manage permissions for any token type through a single interface, dramatically simplifying multi-token applications.

<a id="supported-token-standards"></a>
## 📦 Supported Token Standards

### ERC20 - Fungible Tokens
- **Characteristics**: Divisible, interchangeable tokens
- **Use Case**: Cryptocurrencies, governance tokens, utility tokens
- **Permit3 Handling**: Standard allowance and transfer mechanisms

### ERC721 - Non-Fungible Tokens (NFTs)
- **Characteristics**: Unique, indivisible tokens with individual IDs
- **Use Case**: Digital art, collectibles, gaming assets, real estate
- **Permit3 Handling**: Per-token and collection-wide allowances

### ERC1155 - Semi-Fungible Tokens
- **Characteristics**: Hybrid tokens supporting both fungible and non-fungible properties
- **Use Case**: Gaming items (e.g., 100 swords of type #5), editions, batch minting
- **Permit3 Handling**: Combined tokenId and amount management

### Token Standard Enum

```solidity
enum TokenStandard {
    ERC20,   // Standard fungible tokens
    ERC721,  // Non-fungible tokens (NFTs)
    ERC1155  // Semi-fungible tokens
}
```

<a id="dual-allowance-system"></a>
## 🔄 Dual-Allowance System

A key innovation in MultiTokenPermit is the **dual-allowance system** that provides maximum flexibility for NFT and semi-fungible token permissions.

### How It Works

The system checks two levels of allowances in order:

1. **Per-Token Allowance**: Specific permission for an individual token ID
2. **Collection-Wide Allowance**: Blanket permission for all tokens in a collection

```solidity
// Example flow for ERC721 transfer
1. Check if spender has allowance for specific tokenId #42
2. If not, check if spender has collection-wide allowance for the NFT contract
3. If either check passes, allow the transfer
```

### Benefits

- **Granular Control**: Approve specific NFTs while keeping others restricted
- **Bulk Operations**: Approve entire collections with a single signature
- **Gas Efficiency**: Collection-wide approvals eliminate per-token transactions
- **Backwards Compatible**: Works with existing NFT marketplaces and protocols

### Usage Patterns

```solidity
// Approve a specific NFT (token ID 42)
permit3.approve(nftContract, spender, 42, 1, expiration);

// Approve entire NFT collection (using max uint256 as wildcard)
permit3.approve(nftContract, spender, type(uint256).max, 1, expiration);

// Approve specific ERC1155 token with amount
permit3.approve(erc1155Contract, spender, tokenId, amount, expiration);
```

<a id="tokenid-encoding-as-address"></a>
## 🔐 TokenId Encoding as Address

To efficiently store and manage permissions for millions of potential token IDs, Permit3 uses a deterministic encoding scheme.

### The Encoding Process

```solidity
// Convert token + tokenId into a unique address identifier
address encodedId = address(uint160(uint256(
    keccak256(abi.encodePacked(token, tokenId))
)));
```

### Why This Approach?

1. **Storage Efficiency**: Reuses existing allowance mapping structure
2. **Deterministic**: Same token+ID always produces same encoded address
3. **Collision Resistant**: Keccak256 ensures virtually no collisions
4. **Gas Optimized**: Single storage slot per token ID permission

### Technical Details

The encoding process:
1. Concatenates the token contract address with the token ID
2. Hashes the result using Keccak256 (256-bit output)
3. Truncates to 160 bits (Ethereum address size)
4. Casts to address type for storage in allowance mappings

This creates a unique "virtual address" for each token ID that can be used in the standard allowance storage system:

```solidity
mapping(address owner => 
    mapping(address tokenOrEncodedId => 
        mapping(address spender => Allowance))) allowances;
```

<a id="batch-operations"></a>
## 📦 Batch Operations

MultiTokenPermit supports efficient batch operations for handling multiple tokens in a single transaction.

### Batch Transfer Types

#### 1. Multiple ERC721 Transfers
```solidity
ERC721TransferDetails[] memory transfers = new ERC721TransferDetails[](3);
transfers[0] = ERC721TransferDetails(owner, recipient, tokenId1, nftContract);
transfers[1] = ERC721TransferDetails(owner, recipient, tokenId2, nftContract);
transfers[2] = ERC721TransferDetails(owner, recipient, tokenId3, nftContract);

permit3.transferFrom(transfers);
```

#### 2. ERC1155 Batch Transfer
```solidity
uint256[] memory tokenIds = [1, 2, 3];
uint256[] memory amounts = [100, 50, 25];

ERC1155BatchTransferDetails memory batchTransfer = 
    ERC1155BatchTransferDetails(
        owner,
        recipient, 
        tokenIds,
        amounts,
        erc1155Contract
    );

permit3.batchTransferFrom(batchTransfer);
```

#### 3. Mixed Token Types
```solidity
TokenTypeTransfer[] memory mixedTransfers = new TokenTypeTransfer[](3);

// Add an ERC20 transfer
mixedTransfers[0] = TokenTypeTransfer(
    TokenStandard.ERC20,
    MultiTokenTransfer(owner, recipient, usdcContract, 0, amount)
);

// Add an ERC721 transfer
mixedTransfers[1] = TokenTypeTransfer(
    TokenStandard.ERC721,
    MultiTokenTransfer(owner, recipient, nftContract, tokenId, 1)
);

// Add an ERC1155 transfer
mixedTransfers[2] = TokenTypeTransfer(
    TokenStandard.ERC1155,
    MultiTokenTransfer(owner, recipient, sftContract, tokenId, amount)
);

permit3.batchTransferFrom(mixedTransfers);
```

### Gas Optimization Benefits

- **Single Transaction**: All transfers in one TX saves base gas costs
- **Shared Validation**: Signature verification happens once
- **Batched Events**: Reduced event emission overhead
- **Optimized Loops**: Internal optimizations for batch processing

<a id="use-cases"></a>
## 💡 Use Cases

### NFT Marketplaces
- List multiple NFTs with one signature
- Bulk purchases across collections
- Collection offers and floor sweeping
- Royalty distribution across multiple NFTs

### Gaming Platforms
- Transfer game assets (ERC1155 items)
- Batch crafting operations
- Guild treasury management
- Cross-game asset bridges

### DeFi Protocols
- NFT collateralized lending
- Fractionalized NFT pools
- NFT staking and farming
- Liquidity provision with NFT/token pairs

### Portfolio Management
- Batch transfers for wallet migration
- Multi-asset rebalancing
- Estate planning and inheritance
- DAO treasury operations

### Cross-Chain NFT Bridges
- Unified permissions across chains
- Batch bridging operations
- Collection migrations
- Multi-chain marketplace listings

## 🔍 Technical Implementation Details

### Data Structures

```solidity
// Unified transfer structure for any token type
struct MultiTokenTransfer {
    address from;        // Token owner
    address to;          // Recipient
    address token;       // Token contract
    uint256 tokenId;     // Token ID (0 for ERC20)
    uint160 amount;      // Amount (1 for ERC721)
}

// ERC721-specific transfer
struct ERC721TransferDetails {
    address from;
    address to;
    uint256 tokenId;
    address token;
}

// ERC1155 batch transfer
struct ERC1155BatchTransferDetails {
    address from;
    address to;
    uint256[] tokenIds;
    uint256[] amounts;
    address token;
}
```

### Security Considerations

1. **Safe Transfer Methods**: Always uses `safeTransferFrom` for NFTs
2. **Reentrancy Protection**: Allowance updates before external calls
3. **Overflow Protection**: Amount validation for ERC1155
4. **Permission Verification**: Dual-check system prevents unauthorized transfers

## 🚀 Getting Started

To integrate multi-token support in your application:

1. Deploy or connect to Permit3 with MultiTokenPermit
2. Implement token type detection in your UI
3. Use appropriate approval methods based on token standard
4. Leverage batch operations for gas efficiency

For detailed implementation guidance, see the [Multi-Token Integration Guide](/docs/guides/multi-token-integration.md).

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Allowance System](/docs/concepts/allowance-system.md) | [Concepts](/docs/concepts/README.md) | [Architecture](/docs/concepts/architecture.md) |

[🔝 Back to Top](#multi-token-top)