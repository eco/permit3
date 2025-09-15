<a id="multi-token-signed-permits-top"></a>
# 🎨 Multi-Token Signed Permits Guide 📝

🧭 [Home](/docs/README.md) > [Guides](/docs/guides/README.md) > Multi-Token Signed Permits

This guide explains how to use NFTs (ERC721) and semi-fungible tokens (ERC1155) with Permit3's signed permit functions, including the critical encoding patterns needed for both token types.

###### Navigation: [Important Context](#important-context) | [Encoding TokenIds](#encoding-tokenids) | [Collection-Wide Approvals](#collection-wide-approvals) | [Signed Permit Examples](#signed-permit-examples) | [Cross-Chain NFT Permits](#cross-chain-nft-permits) | [Common Patterns](#common-patterns)

<a id="important-context"></a>
## ⚠️ Important Context

The `AllowanceOrTransfer` struct used in Permit3's signed permit functions is **primarily designed for ERC20 tokens**:

```solidity
struct AllowanceOrTransfer {
    uint48 modeOrExpiration;  // Operation mode or expiration
    address token;            // Token address (or encoded tokenId)
    address account;          // Spender or recipient
    uint160 amountDelta;      // Amount (must be 1 for NFTs)
}
```

**Key Limitation**: This struct doesn't have a dedicated `tokenId` field, so NFT and ERC1155 operations require special encoding.

<a id="encoding-tokenids"></a>
## 🔐 Encoding TokenIds for Multi-Token Permits

To use NFTs (ERC721) or semi-fungible tokens (ERC1155) with signed permits, you must encode the token address and tokenId into a single address value:

### Encoding Formula

```solidity
address encodedTokenId = address(uint160(uint256(
    keccak256(abi.encodePacked(tokenContract, tokenId))
)));
```

### JavaScript Implementation

```javascript
import { ethers } from 'ethers';

function encodeTokenId(tokenContract, tokenId) {
    // Pack token contract and tokenId together
    const packed = ethers.utils.solidityPack(
        ['address', 'uint256'],
        [tokenContract, tokenId]
    );
    
    // Hash the packed data
    const hash = ethers.utils.keccak256(packed);
    
    // Take first 20 bytes (160 bits) as address
    const encodedAddress = ethers.utils.getAddress(
        '0x' + hash.slice(26) // Skip '0x' and first 12 bytes
    );
    
    return encodedAddress;
}
```

### Solidity Helper

```solidity
contract NFTPermitHelper {
    /**
     * @notice Encode NFT token and ID for use in AllowanceOrTransfer
     * @param token The NFT contract address
     * @param tokenId The specific NFT token ID
     * @return The encoded address to use in permit
     */
    function encodeNFT(address token, uint256 tokenId) 
        public 
        pure 
        returns (address) 
    {
        return address(uint160(uint256(
            keccak256(abi.encodePacked(token, tokenId))
        )));
    }
}
```

<a id="collection-wide-approvals"></a>
## 🃏 Collection-Wide Approvals

To approve an entire NFT collection (all token IDs), use the token contract address directly without encoding:

```javascript
// For collection-wide approval, use the token address directly
const collectionApproval = nftContractAddress; // No encoding needed

// For ERC20 tokens, also use the token address directly
const erc20Token = tokenAddress; // No encoding needed
```

### Decision Tree for Token Encoding

```
Is it an NFT/ERC1155 with specific tokenId?
├─ YES → Encode: keccak256(token + tokenId) as address
└─ NO
    ├─ Is it a collection-wide NFT approval?
    │  └─ YES → Use token contract address directly
    └─ Is it an ERC20 token?
       └─ YES → Use token contract address directly
```

<a id="signed-permit-examples"></a>
## 📝 Signed Permit Examples

### Example 1: ERC1155 Semi-Fungible Token Approval

```javascript
async function createERC1155PermitSignature(
    signer,
    erc1155Contract,
    tokenId,
    spender,
    amount,
    expiration
) {
    const permit3 = new ethers.Contract(PERMIT3_ADDRESS, PERMIT3_ABI, signer);
    
    // 1. Encode the ERC1155 tokenId into an address
    const encodedTokenId = encodeTokenId(erc1155Contract, tokenId);
    
    // 2. Create the permit data
    const permits = [{
        modeOrExpiration: expiration, // Must be > 3 for approval
        token: encodedTokenId,         // Encoded token identifier
        account: spender,              // Who can transfer the tokens
        amountDelta: amount            // Amount of ERC1155 tokens
    }];
    
    // 3. Create and sign permit (similar to NFT example)
    // ...
    
    return createSignedPermit(signer, permits);
}
```

### Example 2: Single NFT Approval with Signature

```javascript
async function createNFTPermitSignature(
    signer,
    nftContract,
    tokenId,
    spender,
    expiration
) {
    const permit3 = new ethers.Contract(PERMIT3_ADDRESS, PERMIT3_ABI, signer);
    
    // 1. Encode the NFT tokenId into an address
    const encodedTokenId = encodeTokenId(nftContract, tokenId);
    
    // 2. Create the permit data
    const permits = [{
        modeOrExpiration: expiration, // Must be > 3 for approval
        token: encodedTokenId,         // Encoded NFT identifier
        account: spender,              // Who can transfer the NFT
        amountDelta: 1                 // Always 1 for NFTs
    }];
    
    // 3. Create signature parameters
    const salt = ethers.utils.randomBytes(32);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const timestamp = Math.floor(Date.now() / 1000);
    
    // 4. Create EIP-712 signature
    const domain = {
        name: 'Permit3',
        version: '1',
        chainId: await signer.getChainId(),
        verifyingContract: PERMIT3_ADDRESS
    };
    
    const types = {
        Permit3: [
            { name: 'owner', type: 'address' },
            { name: 'salt', type: 'bytes32' },
            { name: 'deadline', type: 'uint48' },
            { name: 'timestamp', type: 'uint48' },
            { name: 'merkleRoot', type: 'bytes32' }
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
    
    const chainPermits = {
        chainId: await signer.getChainId(),
        permits: permits
    };
    
    // Hash the chain permits
    const merkleRoot = await permit3.hashChainPermits(chainPermits);
    
    const value = {
        owner: await signer.getAddress(),
        salt: salt,
        deadline: deadline,
        timestamp: timestamp,
        merkleRoot: merkleRoot
    };
    
    const signature = await signer._signTypedData(domain, types, value);
    
    return {
        permits,
        salt,
        deadline,
        timestamp,
        signature
    };
}
```

### Example 3: Collection-Wide NFT Approval

```javascript
async function createCollectionPermitSignature(
    signer,
    nftContract,
    spender,
    expiration
) {
    // For collection-wide, use the NFT contract address directly
    const permits = [{
        modeOrExpiration: expiration,
        token: nftContract,      // Direct contract address for collection-wide
        account: spender,
        amountDelta: ethers.constants.MaxUint160 // Max for unlimited
    }];
    
    // Rest of signature creation similar to Example 1
    // ...
}
```

### Example 4: Mixed Token Batch Permit (ERC20 + ERC721 + ERC1155)

```javascript
async function createMixedTokenPermit(
    signer,
    tokens // Array of { type, contract, tokenId, spender, amount }
) {
    const permits = tokens.map(token => {
        let tokenAddress;
        let amount;
        
        if (token.type === 'ERC721') {
            // Encode NFT tokenId
            tokenAddress = encodeTokenId(token.contract, token.tokenId);
            amount = 1;
        } else if (token.type === 'ERC1155') {
            // Encode ERC1155 tokenId
            tokenAddress = encodeTokenId(token.contract, token.tokenId);
            amount = token.amount;
        } else {
            // ERC20: use contract address directly
            tokenAddress = token.contract;
            amount = token.amount;
        }
        
        return {
            modeOrExpiration: token.expiration || Math.floor(Date.now() / 1000) + 86400,
            token: tokenAddress,
            account: token.spender,
            amountDelta: amount
        };
    });
    
    // Create and sign the permit...
}
```

<a id="cross-chain-multi-token-permits"></a>
## 🌉 Cross-Chain Multi-Token Permits

For cross-chain NFT and ERC1155 operations, encode tokenIds on each chain:

```javascript
async function createCrossChainMultiTokenPermit(
    signer,
    tokensByChain // { chainId: { type, contract, tokenIds, amounts, spender }[] }
) {
    const chainPermitsArray = [];
    
    for (const [chainId, tokens] of Object.entries(tokensByChain)) {
        const permits = [];
        
        for (const token of tokens) {
            if (token.type === 'ERC721') {
                // Handle NFTs
                for (const tokenId of token.tokenIds) {
                    const encodedId = encodeTokenId(token.contract, tokenId);
                    permits.push({
                        modeOrExpiration: Math.floor(Date.now() / 1000) + 604800,
                        token: encodedId,
                        account: token.spender,
                        amountDelta: 1
                    });
                }
            } else if (token.type === 'ERC1155') {
                // Handle ERC1155 tokens
                token.tokenIds.forEach((tokenId, index) => {
                    const encodedId = encodeTokenId(token.contract, tokenId);
                    permits.push({
                        modeOrExpiration: Math.floor(Date.now() / 1000) + 604800,
                        token: encodedId,
                        account: token.spender,
                        amountDelta: token.amounts[index]
                    });
                });
            } else if (token.type === 'ERC20') {
                // Handle ERC20 tokens (no encoding needed)
                permits.push({
                    modeOrExpiration: Math.floor(Date.now() / 1000) + 604800,
                    token: token.contract,
                    account: token.spender,
                    amountDelta: token.amount
                });
            }
        }
        
        chainPermitsArray.push({
            chainId: parseInt(chainId),
            permits: permits
        });
    }
    
    // Build merkle tree from all chain permits
    const leaves = await Promise.all(
        chainPermitsArray.map(cp => permit3.hashChainPermits(cp))
    );
    
    const merkleTree = new MerkleTree(leaves);
    const merkleRoot = merkleTree.getRoot();
    
    // Sign the merkle root
    // ... signature creation
    
    return {
        chainPermits: chainPermitsArray,
        merkleRoot,
        proofs: chainPermitsArray.map((_, i) => 
            merkleTree.getProof(leaves[i])
        ),
        signature
    };
}
```

<a id="common-patterns"></a>
## 💡 Common Patterns

### Pattern 1: NFT Marketplace Listing

```javascript
// Seller creates a signed permit for marketplace
async function createMarketplaceListing(
    seller,
    nftContract,
    tokenId,
    marketplaceAddress,
    listingDuration
) {
    const encodedNFT = encodeTokenId(nftContract, tokenId);
    const expiration = Math.floor(Date.now() / 1000) + listingDuration;
    
    const permits = [{
        modeOrExpiration: expiration,
        token: encodedNFT,
        account: marketplaceAddress,
        amountDelta: 1
    }];
    
    // Create signature...
    return createSignedPermit(seller, permits);
}

// Marketplace executes the permit when item is sold
async function executeMarketplaceSale(
    permitData,
    buyer
) {
    // 1. Execute the signed permit to get NFT transfer rights
    await permit3.permit(
        permitData.owner,
        permitData.salt,
        permitData.deadline,
        permitData.timestamp,
        permitData.permits,
        permitData.signature
    );
    
    // 2. Transfer NFT from seller to buyer
    await permit3.transferFrom(
        permitData.owner,  // from (seller)
        buyer,             // to
        nftContract,
        tokenId
    );
}
```

### Pattern 2: Batch NFT Transfer with Signature

```javascript
async function batchNFTTransferWithPermit(
    owner,
    nfts, // Array of { contract, tokenId, recipient }
) {
    // Create permits for batch transfer
    const permits = nfts.map(nft => ({
        modeOrExpiration: 0,  // 0 = immediate transfer mode
        token: encodeTokenId(nft.contract, nft.tokenId),
        account: nft.recipient,
        amountDelta: 1
    }));
    
    // Sign and execute
    const permitData = await createSignedPermit(owner, permits);
    
    await permit3.permit(
        permitData.owner,
        permitData.salt,
        permitData.deadline,
        permitData.timestamp,
        permitData.permits,
        permitData.signature
    );
}
```

### Pattern 3: ERC1155 Gaming Asset Bundle

```javascript
// Bundle multiple game items (ERC1155) in one permit
async function createGameAssetBundle(
    player,
    gameItems // Array of { contract, tokenId, amount }
) {
    const permits = gameItems.map(item => ({
        modeOrExpiration: Math.floor(Date.now() / 1000) + 86400,
        token: encodeTokenId(item.contract, item.tokenId),
        account: GAME_TREASURY_ADDRESS,
        amountDelta: item.amount  // Variable amounts for ERC1155
    }));
    
    return createSignedPermit(player, permits);
}

// Execute the bundle transfer
async function executeGameAssetBundle(permitData) {
    // 1. Execute permit to approve all items
    await permit3.permit(
        permitData.owner,
        permitData.salt,
        permitData.deadline,
        permitData.timestamp,
        permitData.permits,
        permitData.signature
    );
    
    // 2. Transfer each ERC1155 item
    for (const item of gameItems) {
        await permit3['transferFrom(address,address,address,uint256,uint160)'](
            permitData.owner,
            GAME_TREASURY_ADDRESS,
            item.contract,
            item.tokenId,
            item.amount
        );
    }
}
```

### Pattern 4: ERC1155 Fractional Ownership

```javascript
// Create permits for fractional ERC1155 shares
async function createFractionalPermit(
    owner,
    erc1155Contract,
    tokenId,
    shareholders // Array of { address, shares }
) {
    const totalShares = shareholders.reduce((sum, s) => sum + s.shares, 0);
    const encodedId = encodeTokenId(erc1155Contract, tokenId);
    
    // Create transfer permits for each shareholder
    const permits = shareholders.map(shareholder => ({
        modeOrExpiration: 0,  // Immediate transfer
        token: encodedId,
        account: shareholder.address,
        amountDelta: shareholder.shares
    }));
    
    return createSignedPermit(owner, permits);
}
```

## ⚠️ Important Considerations

### 1. Storage Implications

When you encode an NFT as `keccak256(contract + tokenId)`:
- The encoded address is stored in the allowance mapping
- Each NFT approval creates a unique storage slot
- Collection-wide approvals use the contract address directly

### 2. Transfer Function Compatibility

```javascript
// ❌ WRONG: Cannot use standard transferFrom for NFTs
await permit3.transferFrom(from, to, amount, encodedTokenId);

// ✅ CORRECT: Use MultiTokenPermit functions
await permit3['transferFrom(address,address,address,uint256)'](
    from, to, nftContract, tokenId
);
```

### 3. Allowance Queries

```javascript
// Query NFT-specific allowance
const encodedId = encodeTokenId(nftContract, tokenId);
const { amount, expiration } = await permit3.allowance(
    owner,
    encodedId,  // Use encoded address
    spender
);

// Query collection-wide allowance
const { amount: collectionAllowance } = await permit3.allowance(
    owner,
    nftContract,  // Use contract address directly
    spender
);
```

## 🔧 Helper Library

Here's a complete helper library for multi-token permits:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MultiTokenPermitHelper {
    /**
     * Encode token with tokenId for use in AllowanceOrTransfer struct
     * Works for both ERC721 and ERC1155
     */
    function encodeTokenId(address token, uint256 tokenId) 
        internal 
        pure 
        returns (address) 
    {
        return address(uint160(uint256(
            keccak256(abi.encodePacked(token, tokenId))
        )));
    }
    
    /**
     * Create AllowanceOrTransfer for ERC721 NFT approval
     */
    function createNFTPermit(
        address token,
        uint256 tokenId,
        address spender,
        uint48 expiration
    ) internal pure returns (IPermit3.AllowanceOrTransfer memory) {
        return IPermit3.AllowanceOrTransfer({
            modeOrExpiration: expiration,
            token: encodeTokenId(token, tokenId),
            account: spender,
            amountDelta: 1  // Always 1 for NFTs
        });
    }
    
    /**
     * Create AllowanceOrTransfer for ERC1155 approval
     */
    function createERC1155Permit(
        address token,
        uint256 tokenId,
        address spender,
        uint160 amount,
        uint48 expiration
    ) internal pure returns (IPermit3.AllowanceOrTransfer memory) {
        return IPermit3.AllowanceOrTransfer({
            modeOrExpiration: expiration,
            token: encodeTokenId(token, tokenId),
            account: spender,
            amountDelta: amount  // Variable amount for ERC1155
        });
    }
    
    /**
     * Create AllowanceOrTransfer for collection-wide approval
     * Works for both ERC721 and ERC1155 collections
     */
    function createCollectionPermit(
        address token,
        address spender,
        uint48 expiration
    ) internal pure returns (IPermit3.AllowanceOrTransfer memory) {
        return IPermit3.AllowanceOrTransfer({
            modeOrExpiration: expiration,
            token: token, // Direct address for collection-wide
            account: spender,
            amountDelta: type(uint160).max
        });
    }
    
    /**
     * Create AllowanceOrTransfer for ERC20 approval
     */
    function createERC20Permit(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) internal pure returns (IPermit3.AllowanceOrTransfer memory) {
        return IPermit3.AllowanceOrTransfer({
            modeOrExpiration: expiration,
            token: token,  // Direct address for ERC20
            account: spender,
            amountDelta: amount
        });
    }
}
```

## 📚 Related Documentation

- [Multi-Token Support Concepts](/docs/concepts/multi-token-support.md)
- [Signature Creation Guide](/docs/guides/signature-creation.md)
- [Multi-Token Integration Guide](/docs/guides/multi-token-integration.md)
- [Cross-Chain Permits Guide](/docs/guides/cross-chain-permit.md)

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Multi-Token Integration](/docs/guides/multi-token-integration.md) | [Guides](/docs/guides/README.md) | [Cross-Chain Permits](/docs/guides/cross-chain-permit.md) |

[🔝 Back to Top](#multi-token-signed-permits-top)