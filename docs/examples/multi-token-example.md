<a id="multi-token-example-top"></a>
# 🎨 Multi-Token Example: NFT Marketplace with Gaming Assets 🎮

🧭 [Home](/docs/README.md) > [Examples](/docs/examples/README.md) > Multi-Token Example

This example demonstrates building an NFT marketplace that supports multiple token standards including NFTs (ERC721), gaming items (ERC1155), and payment tokens (ERC20).

###### Navigation: [Overview](#overview) | [Smart Contract](#smart-contract-implementation) | [Frontend Integration](#frontend-integration) | [Testing](#testing-the-marketplace) | [Advanced Features](#advanced-features)

<a id="overview"></a>
## 📋 Overview

We'll build a marketplace that:
- Lists NFTs and gaming items for sale
- Accepts multiple payment tokens
- Supports batch purchases
- Implements collection offers
- Uses Permit3's dual-allowance system

<a id="smart-contract-implementation"></a>
## 📄 Smart Contract Implementation

### NFT Marketplace Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IMultiTokenPermit } from "@permit3/interfaces/IMultiTokenPermit.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MultiTokenMarketplace
 * @notice NFT marketplace supporting ERC721, ERC1155, and ERC20 payments
 * @dev Uses Permit3 for unified token permissions
 */
contract MultiTokenMarketplace {
    IMultiTokenPermit public immutable permit3;
    
    struct Listing {
        address seller;
        address tokenContract;
        uint256 tokenId;
        uint256 amount; // 1 for ERC721, variable for ERC1155
        address paymentToken;
        uint256 price;
        IMultiTokenPermit.TokenStandard tokenType;
        bool active;
    }
    
    struct CollectionOffer {
        address buyer;
        address collection;
        address paymentToken;
        uint256 pricePerItem;
        uint256 maxItems;
        uint256 expiry;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(bytes32 => CollectionOffer) public collectionOffers;
    uint256 public nextListingId;
    
    event ItemListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 price
    );
    
    event ItemSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    
    event CollectionOfferCreated(
        bytes32 indexed offerId,
        address indexed buyer,
        address indexed collection,
        uint256 pricePerItem
    );
    
    constructor(address _permit3) {
        permit3 = IMultiTokenPermit(_permit3);
    }
    
    /**
     * @notice List an NFT or gaming item for sale
     * @param tokenContract Address of the token contract
     * @param tokenId Token ID (ignored for ERC20)
     * @param amount Amount (1 for ERC721, variable for ERC1155)
     * @param paymentToken ERC20 token for payment
     * @param price Sale price in payment token
     * @param tokenType Token standard (ERC721, ERC1155, etc.)
     */
    function listItem(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 price,
        IMultiTokenPermit.TokenStandard tokenType
    ) external returns (uint256 listingId) {
        require(price > 0, "Price must be greater than 0");
        require(
            tokenType == IMultiTokenPermit.TokenStandard.ERC721 || 
            tokenType == IMultiTokenPermit.TokenStandard.ERC1155,
            "Only NFTs and gaming items supported"
        );
        
        // For ERC721, amount must be 1
        if (tokenType == IMultiTokenPermit.TokenStandard.ERC721) {
            require(amount == 1, "ERC721 amount must be 1");
            require(
                IERC721(tokenContract).ownerOf(tokenId) == msg.sender,
                "Not token owner"
            );
        } else {
            require(amount > 0, "Amount must be greater than 0");
            uint256 balance = IERC1155(tokenContract).balanceOf(msg.sender, tokenId);
            require(balance >= amount, "Insufficient balance");
        }
        
        listingId = nextListingId++;
        
        listings[listingId] = Listing({
            seller: msg.sender,
            tokenContract: tokenContract,
            tokenId: tokenId,
            amount: amount,
            paymentToken: paymentToken,
            price: price,
            tokenType: tokenType,
            active: true
        });
        
        emit ItemListed(listingId, msg.sender, tokenContract, tokenId, price);
    }
    
    /**
     * @notice Buy a listed item using Permit3 for transfers
     * @param listingId The ID of the listing to purchase
     */
    function buyItem(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        
        // Mark as sold before transfers (reentrancy protection)
        listing.active = false;
        
        // Transfer payment from buyer to seller using Permit3
        permit3.transferFrom(
            msg.sender,
            listing.seller,
            listing.price,
            listing.paymentToken
        );
        
        // Transfer NFT/item from seller to buyer based on token type
        if (listing.tokenType == IMultiTokenPermit.TokenStandard.ERC721) {
            permit3.transferFromERC721(
                listing.seller,
                msg.sender,
                listing.tokenContract,
                listing.tokenId
            );
        } else {
            permit3.transferFromERC1155(
                listing.seller,
                msg.sender,
                listing.tokenContract,
                listing.tokenId,
                uint160(listing.amount)
            );
        }
        
        emit ItemSold(listingId, msg.sender, listing.seller, listing.price);
    }
    
    /**
     * @notice Create a collection-wide offer for any NFT in a collection
     * @param collection The NFT collection address
     * @param paymentToken ERC20 token for payment
     * @param pricePerItem Price per NFT
     * @param maxItems Maximum number of items to buy
     * @param duration Offer duration in seconds
     */
    function createCollectionOffer(
        address collection,
        address paymentToken,
        uint256 pricePerItem,
        uint256 maxItems,
        uint256 duration
    ) external returns (bytes32 offerId) {
        require(pricePerItem > 0, "Price must be greater than 0");
        require(maxItems > 0, "Must offer for at least one item");
        
        offerId = keccak256(
            abi.encodePacked(msg.sender, collection, block.timestamp)
        );
        
        collectionOffers[offerId] = CollectionOffer({
            buyer: msg.sender,
            collection: collection,
            paymentToken: paymentToken,
            pricePerItem: pricePerItem,
            maxItems: maxItems,
            expiry: block.timestamp + duration
        });
        
        emit CollectionOfferCreated(offerId, msg.sender, collection, pricePerItem);
    }
    
    /**
     * @notice Accept a collection offer for your NFT
     * @param offerId The offer ID
     * @param tokenId Your NFT token ID
     */
    function acceptCollectionOffer(
        bytes32 offerId,
        uint256 tokenId
    ) external {
        CollectionOffer storage offer = collectionOffers[offerId];
        require(offer.expiry > block.timestamp, "Offer expired");
        require(offer.maxItems > 0, "Offer fully filled");
        
        // Verify seller owns the NFT
        require(
            IERC721(offer.collection).ownerOf(tokenId) == msg.sender,
            "Not token owner"
        );
        
        // Update offer
        offer.maxItems--;
        
        // Transfer payment to seller
        permit3.transferFrom(
            offer.buyer,
            msg.sender,
            offer.pricePerItem,
            offer.paymentToken
        );
        
        // Transfer NFT to buyer
        permit3.transferFromERC721(
            msg.sender,
            offer.buyer,
            offer.collection,
            tokenId
        );
    }
    
    /**
     * @notice Batch purchase multiple listings
     * @param listingIds Array of listing IDs to purchase
     */
    function batchBuyItems(uint256[] calldata listingIds) external {
        uint256 length = listingIds.length;
        require(length > 0, "No listings provided");
        
        // Prepare batch transfers
        IMultiTokenPermit.TokenTypeTransfer[] memory transfers = 
            new IMultiTokenPermit.TokenTypeTransfer[](length * 2);
        
        uint256 transferIndex = 0;
        
        for (uint256 i = 0; i < length; i++) {
            Listing storage listing = listings[listingIds[i]];
            require(listing.active, "Listing not active");
            
            // Mark as sold
            listing.active = false;
            
            // Add payment transfer
            transfers[transferIndex++] = IMultiTokenPermit.TokenTypeTransfer({
                tokenType: IMultiTokenPermit.TokenStandard.ERC20,
                transfer: IMultiTokenPermit.TokenTransfer({
                    from: msg.sender,
                    to: listing.seller,
                    token: listing.paymentToken,
                    tokenId: 0, // Ignored for ERC20 in TokenTypeTransfer
                    amount: uint160(listing.price)
                })
            });
            
            // Add item transfer
            transfers[transferIndex++] = IMultiTokenPermit.TokenTypeTransfer({
                tokenType: listing.tokenType,
                transfer: IMultiTokenPermit.TokenTransfer({
                    from: listing.seller,
                    to: msg.sender,
                    token: listing.tokenContract,
                    tokenId: listing.tokenId,
                    amount: uint160(listing.amount)
                })
            });
            
            emit ItemSold(listingIds[i], msg.sender, listing.seller, listing.price);
        }
        
        // Execute all transfers in one batch
        permit3.batchTransferMultiToken(transfers);
    }
}
```

<a id="frontend-integration"></a>
## 💻 Frontend Integration

### React Component for Marketplace

```javascript
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useWeb3 } from '@/hooks/useWeb3';

const MultiTokenMarketplace = () => {
    const { provider, signer, account } = useWeb3();
    const [listings, setListings] = useState([]);
    const [selectedItems, setSelectedItems] = useState([]);
    
    // Contract instances
    const [marketplace, setMarketplace] = useState(null);
    const [permit3, setPermit3] = useState(null);
    
    useEffect(() => {
        if (signer) {
            const marketplaceContract = new ethers.Contract(
                MARKETPLACE_ADDRESS,
                MARKETPLACE_ABI,
                signer
            );
            const permit3Contract = new ethers.Contract(
                PERMIT3_ADDRESS,
                PERMIT3_ABI,
                signer
            );
            
            setMarketplace(marketplaceContract);
            setPermit3(permit3Contract);
        }
    }, [signer]);
    
    // Detect token type
    const detectTokenType = async (tokenAddress) => {
        const token = new ethers.Contract(
            tokenAddress,
            ['function supportsInterface(bytes4) view returns (bool)'],
            provider
        );
        
        try {
            // ERC721 interface ID
            if (await token.supportsInterface('0x80ac58cd')) {
                return { type: 'ERC721', enum: 1 };
            }
            // ERC1155 interface ID
            if (await token.supportsInterface('0xd9b67a26')) {
                return { type: 'ERC1155', enum: 2 };
            }
            // Default to ERC20
            return { type: 'ERC20', enum: 0 };
        } catch {
            return { type: 'Unknown', enum: -1 };
        }
    };
    
    // List an item for sale
    const listItem = async (tokenContract, tokenId, amount, paymentToken, price) => {
        try {
            // Detect token type
            const { enum: tokenType } = await detectTokenType(tokenContract);
            
            // First, approve marketplace to spend token via Permit3
            const expiration = Math.floor(Date.now() / 1000) + 86400; // 24 hours
            
            await permit3.approve(
                tokenContract,
                marketplace.address,
                tokenId,
                amount,
                expiration
            );
            
            // List item on marketplace
            const tx = await marketplace.listItem(
                tokenContract,
                tokenId,
                amount,
                paymentToken,
                ethers.utils.parseEther(price),
                tokenType
            );
            
            await tx.wait();
            console.log('Item listed successfully');
            
        } catch (error) {
            console.error('Error listing item:', error);
        }
    };
    
    // Buy a single item
    const buyItem = async (listingId) => {
        try {
            const listing = await marketplace.listings(listingId);
            
            // Approve payment token to Permit3
            const paymentToken = new ethers.Contract(
                listing.paymentToken,
                ERC20_ABI,
                signer
            );
            
            await paymentToken.approve(permit3.address, listing.price);
            
            // Approve Permit3 to spend payment token for marketplace
            await permit3.approve(
                listing.paymentToken,
                marketplace.address,
                listing.price,
                Math.floor(Date.now() / 1000) + 3600
            );
            
            // Buy the item
            const tx = await marketplace.buyItem(listingId);
            await tx.wait();
            
            console.log('Item purchased successfully');
            
        } catch (error) {
            console.error('Error buying item:', error);
        }
    };
    
    // Batch purchase multiple items
    const batchBuy = async () => {
        try {
            // Calculate total payment needed per token
            const paymentsByToken = {};
            
            for (const listingId of selectedItems) {
                const listing = await marketplace.listings(listingId);
                const token = listing.paymentToken;
                const price = listing.price;
                
                if (!paymentsByToken[token]) {
                    paymentsByToken[token] = ethers.BigNumber.from(0);
                }
                paymentsByToken[token] = paymentsByToken[token].add(price);
            }
            
            // Approve all payment tokens
            for (const [token, totalAmount] of Object.entries(paymentsByToken)) {
                const paymentToken = new ethers.Contract(token, ERC20_ABI, signer);
                await paymentToken.approve(permit3.address, totalAmount);
                
                await permit3.approve(
                    token,
                    marketplace.address,
                    0,
                    totalAmount,
                    Math.floor(Date.now() / 1000) + 3600
                );
            }
            
            // Execute batch purchase
            const tx = await marketplace.batchBuyItems(selectedItems);
            await tx.wait();
            
            console.log('Batch purchase successful');
            setSelectedItems([]);
            
        } catch (error) {
            console.error('Error in batch purchase:', error);
        }
    };
    
    // Create collection offer
    const createCollectionOffer = async (
        collection,
        paymentToken,
        pricePerItem,
        maxItems
    ) => {
        try {
            // Calculate total potential payment
            const totalAmount = ethers.utils.parseEther(pricePerItem)
                .mul(maxItems);
            
            // Approve payment token
            const token = new ethers.Contract(paymentToken, ERC20_ABI, signer);
            await token.approve(permit3.address, totalAmount);
            
            // Approve Permit3 for marketplace
            await permit3.approve(
                paymentToken,
                marketplace.address,
                0,
                totalAmount,
                Math.floor(Date.now() / 1000) + 604800 // 1 week
            );
            
            // Create offer
            const tx = await marketplace.createCollectionOffer(
                collection,
                paymentToken,
                ethers.utils.parseEther(pricePerItem),
                maxItems,
                604800 // 1 week duration
            );
            
            await tx.wait();
            console.log('Collection offer created');
            
        } catch (error) {
            console.error('Error creating collection offer:', error);
        }
    };
    
    return (
        <div className="marketplace">
            <h2>🎨 Multi-Token Marketplace</h2>
            
            {/* Listing Form */}
            <div className="list-item-form">
                <h3>List Your Item</h3>
                <TokenSelector onSelect={(token) => setSelectedToken(token)} />
                <input 
                    type="number" 
                    placeholder="Token ID"
                    onChange={(e) => setTokenId(e.target.value)}
                />
                <input 
                    type="number"
                    placeholder="Amount (1 for NFTs)"
                    onChange={(e) => setAmount(e.target.value)}
                />
                <PaymentTokenSelector 
                    onSelect={(token) => setPaymentToken(token)}
                />
                <input 
                    type="text"
                    placeholder="Price"
                    onChange={(e) => setPrice(e.target.value)}
                />
                <button onClick={() => listItem(
                    selectedToken,
                    tokenId,
                    amount,
                    paymentToken,
                    price
                )}>
                    List Item
                </button>
            </div>
            
            {/* Marketplace Grid */}
            <div className="listings-grid">
                {listings.map((listing) => (
                    <ListingCard
                        key={listing.id}
                        listing={listing}
                        onBuy={() => buyItem(listing.id)}
                        onSelect={(id) => {
                            setSelectedItems(prev => 
                                prev.includes(id) 
                                    ? prev.filter(i => i !== id)
                                    : [...prev, id]
                            );
                        }}
                        isSelected={selectedItems.includes(listing.id)}
                    />
                ))}
            </div>
            
            {/* Batch Purchase */}
            {selectedItems.length > 0 && (
                <div className="batch-purchase">
                    <h3>Selected {selectedItems.length} items</h3>
                    <button onClick={batchBuy}>
                        Purchase All Selected
                    </button>
                </div>
            )}
            
            {/* Collection Offers */}
            <CollectionOfferPanel
                onCreate={createCollectionOffer}
                marketplace={marketplace}
            />
        </div>
    );
};

// Listing Card Component
const ListingCard = ({ listing, onBuy, onSelect, isSelected }) => {
    const getTokenTypeIcon = (type) => {
        switch(type) {
            case 'ERC721': return '🖼️';
            case 'ERC1155': return '🎮';
            case 'ERC20': return '🪙';
            default: return '❓';
        }
    };
    
    return (
        <div className={`listing-card ${isSelected ? 'selected' : ''}`}>
            <div className="token-type">
                {getTokenTypeIcon(listing.tokenType)}
            </div>
            <h4>{listing.name || `Token #${listing.tokenId}`}</h4>
            <p>Price: {ethers.utils.formatEther(listing.price)} {listing.paymentSymbol}</p>
            {listing.tokenType === 'ERC1155' && (
                <p>Amount: {listing.amount}</p>
            )}
            <div className="card-actions">
                <button onClick={onBuy}>Buy Now</button>
                <input 
                    type="checkbox"
                    checked={isSelected}
                    onChange={() => onSelect(listing.id)}
                />
            </div>
        </div>
    );
};
```

<a id="testing-the-marketplace"></a>
## 🧪 Testing the Marketplace

### Hardhat Test Suite

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MultiTokenMarketplace", function () {
    let marketplace, permit3;
    let nft, gameItem, paymentToken;
    let owner, seller, buyer;
    
    beforeEach(async function () {
        [owner, seller, buyer] = await ethers.getSigners();
        
        // Deploy Permit3
        const Permit3 = await ethers.getContractFactory("Permit3");
        permit3 = await Permit3.deploy();
        
        // Deploy marketplace
        const Marketplace = await ethers.getContractFactory("MultiTokenMarketplace");
        marketplace = await Marketplace.deploy(permit3.address);
        
        // Deploy test tokens
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        nft = await MockERC721.deploy();
        
        const MockERC1155 = await ethers.getContractFactory("MockERC1155");
        gameItem = await MockERC1155.deploy();
        
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        paymentToken = await MockERC20.deploy();
        
        // Setup: Mint tokens and approve Permit3
        await nft.connect(seller).mint(seller.address);
        await nft.connect(seller).setApprovalForAll(permit3.address, true);
        
        await gameItem.connect(seller).mint(seller.address, 1, 100, "0x");
        await gameItem.connect(seller).setApprovalForAll(permit3.address, true);
        
        await paymentToken.connect(buyer).mint(
            buyer.address,
            ethers.utils.parseEther("1000")
        );
        await paymentToken.connect(buyer).approve(
            permit3.address,
            ethers.constants.MaxUint256
        );
    });
    
    describe("Listing Items", function () {
        it("Should list an ERC721 NFT", async function () {
            await permit3.connect(seller).approve(
                nft.address,
                marketplace.address,
                0, // Token ID
                1, // Amount (always 1 for NFT)
                Math.floor(Date.now() / 1000) + 86400
            );
            
            await expect(
                marketplace.connect(seller).listItem(
                    nft.address,
                    0,
                    1,
                    paymentToken.address,
                    ethers.utils.parseEther("10"),
                    1 // TokenStandard.ERC721
                )
            ).to.emit(marketplace, "ItemListed");
            
            const listing = await marketplace.listings(0);
            expect(listing.seller).to.equal(seller.address);
            expect(listing.tokenContract).to.equal(nft.address);
            expect(listing.price).to.equal(ethers.utils.parseEther("10"));
        });
        
        it("Should list ERC1155 game items", async function () {
            await permit3.connect(seller).approve(
                gameItem.address,
                marketplace.address,
                1, // Token ID
                50, // Amount
                Math.floor(Date.now() / 1000) + 86400
            );
            
            await marketplace.connect(seller).listItem(
                gameItem.address,
                1,
                50,
                paymentToken.address,
                ethers.utils.parseEther("5"),
                2 // TokenStandard.ERC1155
            );
            
            const listing = await marketplace.listings(0);
            expect(listing.amount).to.equal(50);
            expect(listing.tokenType).to.equal(2);
        });
    });
    
    describe("Purchasing Items", function () {
        beforeEach(async function () {
            // List an NFT
            await permit3.connect(seller).approve(
                nft.address,
                marketplace.address,
                0,
                1,
                Math.floor(Date.now() / 1000) + 86400
            );
            
            await marketplace.connect(seller).listItem(
                nft.address,
                0,
                1,
                paymentToken.address,
                ethers.utils.parseEther("10"),
                1
            );
            
            // Approve payment
            await permit3.connect(buyer).approve(
                paymentToken.address,
                marketplace.address,
                0,
                ethers.utils.parseEther("10"),
                Math.floor(Date.now() / 1000) + 86400
            );
        });
        
        it("Should purchase an NFT", async function () {
            await expect(
                marketplace.connect(buyer).buyItem(0)
            ).to.emit(marketplace, "ItemSold");
            
            expect(await nft.ownerOf(0)).to.equal(buyer.address);
            expect(
                await paymentToken.balanceOf(seller.address)
            ).to.equal(ethers.utils.parseEther("10"));
        });
        
        it("Should handle batch purchases", async function () {
            // List another item
            await gameItem.connect(seller).mint(seller.address, 2, 100, "0x");
            
            await permit3.connect(seller).approve(
                gameItem.address,
                marketplace.address,
                2,
                100,
                Math.floor(Date.now() / 1000) + 86400
            );
            
            await marketplace.connect(seller).listItem(
                gameItem.address,
                2,
                100,
                paymentToken.address,
                ethers.utils.parseEther("5"),
                2
            );
            
            // Approve total payment
            await permit3.connect(buyer).approve(
                paymentToken.address,
                marketplace.address,
                0,
                ethers.utils.parseEther("15"),
                Math.floor(Date.now() / 1000) + 86400
            );
            
            // Batch purchase
            await marketplace.connect(buyer).batchBuyItems([0, 1]);
            
            expect(await nft.ownerOf(0)).to.equal(buyer.address);
            expect(
                await gameItem.balanceOf(buyer.address, 2)
            ).to.equal(100);
        });
    });
    
    describe("Collection Offers", function () {
        it("Should create and accept collection offers", async function () {
            // Buyer creates collection offer
            await permit3.connect(buyer).approve(
                paymentToken.address,
                marketplace.address,
                0,
                ethers.utils.parseEther("100"),
                Math.floor(Date.now() / 1000) + 604800
            );
            
            const tx = await marketplace.connect(buyer).createCollectionOffer(
                nft.address,
                paymentToken.address,
                ethers.utils.parseEther("10"),
                10,
                604800
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(
                e => e.event === "CollectionOfferCreated"
            );
            const offerId = event.args.offerId;
            
            // Seller accepts offer
            await permit3.connect(seller).approve(
                nft.address,
                marketplace.address,
                0,
                1,
                Math.floor(Date.now() / 1000) + 86400
            );
            
            await marketplace.connect(seller).acceptCollectionOffer(
                offerId,
                0
            );
            
            expect(await nft.ownerOf(0)).to.equal(buyer.address);
        });
    });
});
```

<a id="advanced-features"></a>
## 🚀 Advanced Features

### Auction System with Multi-Token Support

```solidity
contract MultiTokenAuction {
    IMultiTokenPermit public permit3;
    
    struct Auction {
        address seller;
        address tokenContract;
        uint256 tokenId;
        uint256 amount;
        IMultiTokenPermit.TokenStandard tokenType;
        address paymentToken;
        uint256 startingBid;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool ended;
    }
    
    mapping(uint256 => Auction) public auctions;
    
    function createAuction(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        IMultiTokenPermit.TokenStandard tokenType,
        address paymentToken,
        uint256 startingBid,
        uint256 duration
    ) external returns (uint256 auctionId) {
        // Implementation
    }
    
    function bid(uint256 auctionId, uint256 bidAmount) external {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp < auction.endTime, "Auction ended");
        require(bidAmount > auction.highestBid, "Bid too low");
        
        // Refund previous bidder if exists
        if (auction.highestBidder != address(0)) {
            permit3.transferFrom(
                address(this),
                auction.highestBidder,
                auction.highestBid,
                auction.paymentToken
            );
        }
        
        // Accept new bid
        permit3.transferFrom(
            msg.sender,
            address(this),
            bidAmount,
            auction.paymentToken
        );
        
        auction.highestBid = bidAmount;
        auction.highestBidder = msg.sender;
    }
}
```

### Fractional NFT Trading

```solidity
contract FractionalNFTTrading {
    IMultiTokenPermit public permit3;
    
    struct FractionalNFT {
        address originalNFT;
        uint256 tokenId;
        address fractionalToken; // ERC1155 representing shares
        uint256 totalShares;
    }
    
    function fractionalize(
        address nftContract,
        uint256 tokenId,
        uint256 shares
    ) external {
        // Transfer NFT to this contract via Permit3
        permit3.transferFromERC721(
            msg.sender,
            address(this),
            nftContract,
            tokenId
        );
        
        // Mint fractional shares as ERC1155
        // Implementation details...
    }
}
```

## 📊 Gas Optimization Analysis

```javascript
// Gas comparison for different operations
const gasAnalysis = {
    singleNFTTransfer: {
        traditional: "~85,000 gas",
        withPermit3: "~95,000 gas",
        benefit: "No separate approval TX needed"
    },
    batchTransfer10Items: {
        traditional: "~850,000 gas (10 transactions)",
        withPermit3: "~350,000 gas (1 transaction)",
        savings: "~59% gas saved"
    },
    collectionApproval: {
        traditional: "~45,000 gas per NFT",
        withPermit3: "~65,000 gas for entire collection",
        benefit: "One-time approval for unlimited NFTs"
    }
};
```

## 🔒 Security Best Practices

1. **Always verify token ownership before listing**
2. **Use reentrancy guards for critical functions**
3. **Implement proper access controls**
4. **Validate token standards before operations**
5. **Set reasonable expiration times for approvals**
6. **Monitor for unusual approval patterns**

## 📚 Additional Resources

- [Multi-Token Support Concepts](/docs/concepts/multi-token-support.md)
- [Multi-Token Integration Guide](/docs/guides/multi-token-integration.md)
- [IMultiTokenPermit Interface](/docs/api/interfaces.md#imultitokenpermit)
- [Gas Optimization Guide](/docs/guides/gas-optimization.md)

---

| ⬅️ Previous | 🏠 Section | ➡️ Next |
|:-----------|:----------:|------------:|
| [Cross-Chain Example](/docs/examples/cross-chain-example.md) | [Examples](/docs/examples/README.md) | [Security Example](/docs/examples/security-example.md) |

[🔝 Back to Top](#multi-token-example-top)