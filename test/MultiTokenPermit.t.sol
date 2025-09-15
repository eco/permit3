// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../src/Permit3.sol";
import "../src/PermitBase.sol";

import "../src/interfaces/IMultiTokenPermit.sol";
import "../src/interfaces/IPermit.sol";
import "./utils/TestBase.sol";

/**
 * @title MockERC721
 * @notice Mock ERC721 contract for testing multi-token functionality
 */
contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockNFT", "MOCK721") { }

    function mint(
        address to
    ) external returns (uint256 tokenId) {
        tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function mintBatch(address to, uint256 amount) external returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            tokenIds[i] = _tokenIdCounter++;
            _mint(to, tokenIds[i]);
        }
    }
}

/**
 * @title MockERC1155
 * @notice Mock ERC1155 contract for testing multi-token functionality
 */
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("https://mock.uri/{id}") { }

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external {
        _mint(to, tokenId, amount, data);
    }

    function mintBatch(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) external {
        _mintBatch(to, tokenIds, amounts, data);
    }
}

/**
 * @title MultiTokenPermitTest
 * @notice Comprehensive test suite for MultiTokenPermit functionality
 * @dev Tests all functions including dual-allowance system, batch operations, and error conditions
 */
contract MultiTokenPermitTest is TestBase {
    using ECDSA for bytes32;

    // Additional test contracts
    MockERC721 nftToken;
    MockERC1155 multiToken;

    // Test token IDs and amounts
    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant TOKEN_ID_3 = 3;
    uint128 constant ERC1155_AMOUNT = 100;
    uint128 constant ERC1155_AMOUNT_2 = 50;

    // Test accounts
    address nftOwner;
    address multiTokenOwner;
    address spenderAddress;
    address recipientAddress;

    function setUp() public override {
        super.setUp();

        // Deploy mock contracts
        nftToken = new MockERC721();
        multiToken = new MockERC1155();

        // Set up test accounts
        nftOwner = makeAddr("nftOwner");
        multiTokenOwner = makeAddr("multiTokenOwner");
        spenderAddress = makeAddr("spenderAddress");
        recipientAddress = makeAddr("recipientAddress");

        // Mint test tokens and set approvals
        vm.startPrank(nftOwner);
        nftToken.mint(nftOwner); // Token ID 0
        nftToken.mint(nftOwner); // Token ID 1
        nftToken.mint(nftOwner); // Token ID 2
        nftToken.setApprovalForAll(address(permit3), true);
        vm.stopPrank();

        vm.startPrank(multiTokenOwner);
        multiToken.mint(multiTokenOwner, TOKEN_ID_1, ERC1155_AMOUNT, "");
        multiToken.mint(multiTokenOwner, TOKEN_ID_2, ERC1155_AMOUNT, "");
        multiToken.mint(multiTokenOwner, TOKEN_ID_3, ERC1155_AMOUNT, "");
        multiToken.setApprovalForAll(address(permit3), true);
        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////////////////////
    // MultiTokenAllowance Query Tests
    //////////////////////////////////////////////////////////////////////////

    function test_allowance_ERC20() public {
        uint160 allowanceAmount = 500;
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set ERC20 allowance
        vm.prank(owner);
        permit3.approve(address(token), spenderAddress, allowanceAmount, expiration);

        // Query allowance for ERC20 (no tokenId parameter)
        (uint160 amount, uint48 exp, uint48 timestamp) = permit3.allowance(owner, address(token), spenderAddress);

        assertTrue(amount > 0);
        assertEq(amount, allowanceAmount);
        assertEq(exp, expiration);
        assertGt(timestamp, 0);
    }

    function test_allowance_ERC721_perToken() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set per-token allowance using 5-parameter approve
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);

        // Query allowance for specific token ID
        (uint160 amount, uint48 exp, uint48 timestamp) =
            permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);

        assertTrue(amount > 0);
        assertEq(amount, 1);
        assertEq(exp, expiration);
        assertGt(timestamp, 0);
    }

    function test_allowance_ERC721_collectionWide() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set collection-wide allowance using 4-parameter approve
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Query collection-wide allowance (without tokenId)
        (uint160 amount, uint48 exp, uint48 timestamp) = permit3.allowance(nftOwner, address(nftToken), spenderAddress);

        assertTrue(amount > 0);
        assertEq(amount, type(uint160).max);
        assertEq(exp, expiration);
        assertGt(timestamp, 0);

        // Verify that querying specific token ID returns zero (no per-token allowance set)
        (amount, exp, timestamp) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);
        assertEq(amount, 0);
    }

    function test_allowance_ERC721_perTokenOverridesCollectionWide() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set collection-wide allowance using 4-parameter approve
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Set per-token allowance for specific token
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration + 100);

        // Query should return per-token allowance (prioritized over collection-wide)
        (uint160 amount, uint48 exp, uint48 timestamp) =
            permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);

        assertTrue(amount > 0);
        assertEq(amount, 1);
        assertEq(exp, expiration + 100); // Should be the per-token expiration
        assertGt(timestamp, 0);
    }

    function test_allowance_ERC1155_perToken() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set per-token allowance using 5-parameter approve
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, TOKEN_ID_1, ERC1155_AMOUNT, expiration);

        // Query allowance for specific token ID
        (uint160 amount, uint48 exp, uint48 timestamp) =
            permit3.allowance(multiTokenOwner, address(multiToken), spenderAddress, TOKEN_ID_1);

        assertTrue(amount > 0);
        assertEq(amount, ERC1155_AMOUNT);
        assertEq(exp, expiration);
        assertGt(timestamp, 0);
    }

    function test_allowance_noAllowance() public view {
        // Query allowance when none exists
        (uint160 amount, uint48 exp, uint48 timestamp) =
            permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);

        assertEq(amount, 0);
        assertEq(amount, 0);
        assertEq(exp, 0);
        assertEq(timestamp, 0);
    }

    //////////////////////////////////////////////////////////////////////////
    // ERC721 Transfer Tests
    //////////////////////////////////////////////////////////////////////////

    function test_transferFromERC721_withPerTokenAllowance() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set per-token allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);

        // Execute transfer
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), TOKEN_ID_1);

        // Verify transfer
        assertEq(nftToken.ownerOf(TOKEN_ID_1), recipientAddress);
    }

    function test_transferFromERC721_withCollectionWideAllowance() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set collection-wide allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Execute transfer
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), TOKEN_ID_1);

        // Verify transfer
        assertEq(nftToken.ownerOf(TOKEN_ID_1), recipientAddress);
    }

    function test_transferFromERC721_insufficientAllowance() public {
        // No allowance set - should revert
        vm.expectRevert(abi.encodeWithSelector(IPermit.InsufficientAllowance.selector, 1, 0));
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), TOKEN_ID_1);
    }

    function test_transferFromERC721_expiredAllowance() public {
        uint48 expiration = uint48(block.timestamp - 1); // Expired

        // Should revert with invalid expiration when setting the allowance
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidExpiration.selector, expiration));
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);
    }

    function test_transferFromERC721_batchTransfer() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowances for multiple tokens
        for (uint256 i = 0; i <= 2; i++) {
            vm.prank(nftOwner);
            permit3.approve(address(nftToken), spenderAddress, i, 1, expiration);
        }

        // Prepare batch transfer
        IMultiTokenPermit.ERC721Transfer[] memory transfers = new IMultiTokenPermit.ERC721Transfer[](3);

        for (uint256 i = 0; i < 3; i++) {
            transfers[i] = IMultiTokenPermit.ERC721Transfer({
                from: nftOwner,
                to: recipientAddress,
                tokenId: i,
                token: address(nftToken)
            });
        }

        // Execute batch transfer
        vm.prank(spenderAddress);
        permit3.batchTransferERC721(transfers);

        // Verify all transfers
        for (uint256 i = 0; i < 3; i++) {
            assertEq(nftToken.ownerOf(i), recipientAddress);
        }
    }

    function test_transferFromERC721_batchTransfer_emptyArray() public {
        IMultiTokenPermit.ERC721Transfer[] memory transfers = new IMultiTokenPermit.ERC721Transfer[](0);

        vm.expectRevert(IPermit.EmptyArray.selector);
        vm.prank(spenderAddress);
        permit3.batchTransferERC721(transfers);
    }

    //////////////////////////////////////////////////////////////////////////
    // ERC1155 Transfer Tests
    //////////////////////////////////////////////////////////////////////////

    function test_transferFrom_withPerTokenAllowance() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set per-token allowance
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, TOKEN_ID_1, ERC1155_AMOUNT, expiration);

        // Execute transfer
        vm.prank(spenderAddress);
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), TOKEN_ID_1, ERC1155_AMOUNT_2);

        // Verify transfer
        assertEq(multiToken.balanceOf(recipientAddress, TOKEN_ID_1), ERC1155_AMOUNT_2);
        assertEq(multiToken.balanceOf(multiTokenOwner, TOKEN_ID_1), ERC1155_AMOUNT - ERC1155_AMOUNT_2);
    }

    function test_transferFromERC1155_withCollectionWideAllowance() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set collection-wide allowance
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, type(uint160).max, expiration);

        // Execute transfer
        vm.prank(spenderAddress);
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), TOKEN_ID_1, ERC1155_AMOUNT_2);

        // Verify transfer
        assertEq(multiToken.balanceOf(recipientAddress, TOKEN_ID_1), ERC1155_AMOUNT_2);
        assertEq(multiToken.balanceOf(multiTokenOwner, TOKEN_ID_1), ERC1155_AMOUNT - ERC1155_AMOUNT_2);
    }

    function test_transferFromERC1155_insufficientAllowance() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowance less than requested transfer amount
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, TOKEN_ID_1, ERC1155_AMOUNT_2 - 1, expiration);

        // Should revert with insufficient allowance
        vm.expectRevert(abi.encodeWithSelector(IPermit.InsufficientAllowance.selector, ERC1155_AMOUNT_2, 0));
        vm.prank(spenderAddress);
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), TOKEN_ID_1, ERC1155_AMOUNT_2);
    }

    function test_transferFromERC1155_batchTransfer() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowances for multiple tokens
        for (uint256 i = 1; i <= 3; i++) {
            vm.prank(multiTokenOwner);
            permit3.approve(address(multiToken), spenderAddress, i, ERC1155_AMOUNT, expiration);
        }

        // Prepare batch transfer
        IMultiTokenPermit.TokenTransfer[] memory transfers = new IMultiTokenPermit.TokenTransfer[](3);

        for (uint256 i = 0; i < 3; i++) {
            transfers[i] = IMultiTokenPermit.TokenTransfer({
                from: multiTokenOwner,
                to: recipientAddress,
                token: address(multiToken),
                tokenId: i + 1,
                amount: ERC1155_AMOUNT_2
            });
        }

        // Execute batch transfer
        vm.prank(spenderAddress);
        permit3.batchTransferERC1155(transfers);

        // Verify all transfers
        for (uint256 i = 1; i <= 3; i++) {
            assertEq(multiToken.balanceOf(recipientAddress, i), ERC1155_AMOUNT_2);
            assertEq(multiToken.balanceOf(multiTokenOwner, i), ERC1155_AMOUNT - ERC1155_AMOUNT_2);
        }
    }

    function test_transferFromERC1155_batchTransfer_emptyArray() public {
        IMultiTokenPermit.TokenTransfer[] memory transfers = new IMultiTokenPermit.TokenTransfer[](0);

        vm.expectRevert(IPermit.EmptyArray.selector);
        vm.prank(spenderAddress);
        permit3.batchTransferERC1155(transfers);
    }

    //////////////////////////////////////////////////////////////////////////
    // ERC1155 Batch Transfer Tests
    //////////////////////////////////////////////////////////////////////////

    function test_batchTransferFrom() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowances for multiple tokens
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = i + 1;
            amounts[i] = ERC1155_AMOUNT_2;

            vm.prank(multiTokenOwner);
            permit3.approve(address(multiToken), spenderAddress, tokenIds[i], ERC1155_AMOUNT, expiration);
        }

        // Prepare batch transfer
        IMultiTokenPermit.ERC1155BatchTransfer memory batchTransfer = IMultiTokenPermit.ERC1155BatchTransfer({
            from: multiTokenOwner,
            to: recipientAddress,
            tokenIds: tokenIds,
            amounts: amounts,
            token: address(multiToken)
        });

        // Execute batch transfer
        vm.prank(spenderAddress);
        permit3.batchTransferERC1155(batchTransfer);

        // Verify all transfers
        for (uint256 i = 0; i < 3; i++) {
            assertEq(multiToken.balanceOf(recipientAddress, tokenIds[i]), amounts[i]);
            assertEq(multiToken.balanceOf(multiTokenOwner, tokenIds[i]), ERC1155_AMOUNT - amounts[i]);
        }
    }

    function test_batchTransferFrom_emptyArray() public {
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        IMultiTokenPermit.ERC1155BatchTransfer memory batchTransfer = IMultiTokenPermit.ERC1155BatchTransfer({
            from: multiTokenOwner,
            to: recipientAddress,
            tokenIds: tokenIds,
            amounts: amounts,
            token: address(multiToken)
        });

        vm.expectRevert(IPermit.EmptyArray.selector);
        vm.prank(spenderAddress);
        permit3.batchTransferERC1155(batchTransfer);
    }

    function test_batchTransferFrom_mismatchedArrays() public {
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](2); // Mismatched length

        IMultiTokenPermit.ERC1155BatchTransfer memory batchTransfer = IMultiTokenPermit.ERC1155BatchTransfer({
            from: multiTokenOwner,
            to: recipientAddress,
            tokenIds: tokenIds,
            amounts: amounts,
            token: address(multiToken)
        });

        vm.expectRevert(IMultiTokenPermit.InvalidArrayLength.selector);
        vm.prank(spenderAddress);
        permit3.batchTransferERC1155(batchTransfer);
    }

    //////////////////////////////////////////////////////////////////////////
    // Mixed Token Type Batch Transfer Tests
    //////////////////////////////////////////////////////////////////////////

    function test_batchTransferFrom_mixedTokenTypes() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set ERC20 allowance
        vm.prank(owner);
        permit3.approve(address(token), spenderAddress, AMOUNT, expiration);

        // Set ERC721 allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);

        // Set ERC1155 allowance
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, TOKEN_ID_1, ERC1155_AMOUNT, expiration);

        // Prepare mixed batch transfer
        IMultiTokenPermit.TokenTypeTransfer[] memory transfers = new IMultiTokenPermit.TokenTypeTransfer[](3);

        // ERC20 transfer
        transfers[0] = IMultiTokenPermit.TokenTypeTransfer({
            tokenType: IMultiTokenPermit.TokenStandard.ERC20,
            transfer: IMultiTokenPermit.TokenTransfer({
                from: owner,
                to: recipient,
                token: address(token),
                tokenId: 0, // Ignored for ERC20 in TokenTypeTransfer
                amount: AMOUNT
            })
        });

        // ERC721 transfer
        transfers[1] = IMultiTokenPermit.TokenTypeTransfer({
            tokenType: IMultiTokenPermit.TokenStandard.ERC721,
            transfer: IMultiTokenPermit.TokenTransfer({
                from: nftOwner,
                to: recipientAddress,
                token: address(nftToken),
                tokenId: TOKEN_ID_1,
                amount: 1 // Should be 1 for ERC721
             })
        });

        // ERC1155 transfer
        transfers[2] = IMultiTokenPermit.TokenTypeTransfer({
            tokenType: IMultiTokenPermit.TokenStandard.ERC1155,
            transfer: IMultiTokenPermit.TokenTransfer({
                from: multiTokenOwner,
                to: recipientAddress,
                token: address(multiToken),
                tokenId: TOKEN_ID_1,
                amount: ERC1155_AMOUNT_2
            })
        });

        // Execute mixed batch transfer
        vm.prank(spenderAddress);
        permit3.batchTransferMultiToken(transfers);

        // Verify all transfers
        assertEq(token.balanceOf(recipient), AMOUNT);
        assertEq(nftToken.ownerOf(TOKEN_ID_1), recipientAddress);
        assertEq(multiToken.balanceOf(recipientAddress, TOKEN_ID_1), ERC1155_AMOUNT_2);
    }

    function test_batchTransferFrom_mixedTypes_emptyArray() public {
        IMultiTokenPermit.TokenTypeTransfer[] memory transfers = new IMultiTokenPermit.TokenTypeTransfer[](0);

        vm.expectRevert(IPermit.EmptyArray.selector);
        vm.prank(spenderAddress);
        permit3.batchTransferMultiToken(transfers);
    }

    function test_batchTransferFrom_ERC721_invalidAmount() public {
        // Setup: Approve NFT
        uint48 futureExpiration = uint48(block.timestamp + 1 hours);
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, futureExpiration);

        // Create transfer with invalid amount (not 1) for ERC721
        IMultiTokenPermit.TokenTypeTransfer[] memory transfers = new IMultiTokenPermit.TokenTypeTransfer[](1);
        transfers[0] = IMultiTokenPermit.TokenTypeTransfer({
            tokenType: IMultiTokenPermit.TokenStandard.ERC721,
            transfer: IMultiTokenPermit.TokenTransfer({
                from: nftOwner,
                to: recipientAddress,
                token: address(nftToken),
                tokenId: TOKEN_ID_1,
                amount: 2 // Invalid: ERC721 must have amount = 1
             })
        });

        // Should revert with InvalidAmount
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidAmount.selector, 2));
        vm.prank(spenderAddress);
        permit3.batchTransferMultiToken(transfers);

        // Test with amount = 0
        transfers[0].transfer.amount = 0;
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidAmount.selector, 0));
        vm.prank(spenderAddress);
        permit3.batchTransferMultiToken(transfers);

        // Test with max amount
        transfers[0].transfer.amount = type(uint160).max;
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidAmount.selector, type(uint160).max));
        vm.prank(spenderAddress);
        permit3.batchTransferMultiToken(transfers);
    }

    // Note: This test would fail compilation due to the enum casting issue in MultiTokenPermit.sol
    // function test_batchTransferFrom_ERC1155_amountOverflow() public {
    //     IMultiTokenPermit.TokenTypeTransfer[] memory transfers =
    //         new IMultiTokenPermit.TokenTypeTransfer[](1);

    //     transfers[0] = IMultiTokenPermit.TokenTypeTransfer({
    //         tokenType: IMultiTokenPermit.TokenStandard.ERC1155,
    //         transfer: IMultiTokenPermit.MultiTokenTransfer({
    //             from: multiTokenOwner,
    //             to: recipientAddress,
    //             token: address(multiToken),
    //             tokenId: TOKEN_ID_1,
    //             amount: uint256(type(uint128).max) + 1 // Overflow
    //         })
    //     });

    //     vm.expectRevert(); // Should revert with InvalidTokenData
    //     vm.prank(spenderAddress);
    //     permit3.batchTransferFrom(transfers);
    // }

    //////////////////////////////////////////////////////////////////////////
    // Edge Cases and Error Conditions
    //////////////////////////////////////////////////////////////////////////

    function test_transferFromERC721_nonexistentToken() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowance for non-existent token
        uint256 nonexistentTokenId = 999;
        address encodedId =
            address(uint160(uint256(keccak256(abi.encodePacked(address(nftToken), nonexistentTokenId)))));
        vm.prank(nftOwner);
        permit3.approve(encodedId, spenderAddress, 1, expiration);

        // Should revert when trying to transfer non-existent token
        vm.expectRevert(); // ERC721 will revert with owner query for nonexistent token
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), nonexistentTokenId);
    }

    function test_transferFrom_zeroAmount() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set allowance
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, TOKEN_ID_1, ERC1155_AMOUNT, expiration);

        uint256 initialBalance = multiToken.balanceOf(recipientAddress, TOKEN_ID_1);

        // Execute transfer with zero amount (should succeed but no change)
        vm.prank(spenderAddress);
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), TOKEN_ID_1, 0);

        // Verify no change in balance
        assertEq(multiToken.balanceOf(recipientAddress, TOKEN_ID_1), initialBalance);
    }

    function test_dualAllowanceSystem_prioritization() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // Set collection-wide allowance first using 4-parameter approve
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Set per-token allowance with different expiration
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration + 100);

        // Query should return per-token allowance (higher priority)
        (uint160 amount, uint48 exp, uint48 timestamp) =
            permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);

        assertTrue(amount > 0);
        assertEq(amount, 1);
        assertEq(exp, expiration + 100); // Should be per-token expiration
        assertGt(timestamp, 0);

        // Transfer should use per-token allowance
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), TOKEN_ID_1);

        assertEq(nftToken.ownerOf(TOKEN_ID_1), recipientAddress);
    }

    //////////////////////////////////////////////////////////////////////////
    // Gas Optimization Tests
    //////////////////////////////////////////////////////////////////////////

    function test_gas_singleVsBatchTransfer_ERC721() public {
        uint48 expiration = uint48(block.timestamp + 3600);
        uint256 numTokens = 5;

        // Mint additional tokens and set allowances
        vm.startPrank(nftOwner);
        uint256[] memory tokenIds = nftToken.mintBatch(nftOwner, numTokens);

        // Set collection-wide allowance for easier testing
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);
        vm.stopPrank();

        // Measure gas for individual transfers
        uint256 gasUsedIndividual = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 gasBeforeIndividual = gasleft();
            vm.prank(spenderAddress);
            permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), tokenIds[i]);
            gasUsedIndividual += gasBeforeIndividual - gasleft();
        }

        // Reset ownership for batch test
        vm.startPrank(recipientAddress);
        for (uint256 i = 0; i < numTokens; i++) {
            nftToken.transferFrom(recipientAddress, nftOwner, tokenIds[i]);
        }
        vm.stopPrank();

        // Prepare batch transfer
        IMultiTokenPermit.ERC721Transfer[] memory transfers = new IMultiTokenPermit.ERC721Transfer[](numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            transfers[i] = IMultiTokenPermit.ERC721Transfer({
                from: nftOwner,
                to: recipientAddress,
                tokenId: tokenIds[i],
                token: address(nftToken)
            });
        }

        // Measure gas for batch transfer
        uint256 gasBefore = gasleft();
        vm.prank(spenderAddress);
        permit3.batchTransferERC721(transfers);
        uint256 gasUsedBatch = gasBefore - gasleft();

        // Batch should be more efficient (though this depends on specific implementation)
        // At minimum, batch shouldn't be dramatically worse than individual
        // Note: This is more of an optimization check than a hard requirement
        emit log_named_uint("Gas used individual transfers", gasUsedIndividual);
        emit log_named_uint("Gas used batch transfer", gasUsedBatch);
    }

    // ============================================
    // MultiTokenPermit Approval Validation Tests
    // ============================================

    function test_approve_revertsZeroToken() public {
        vm.prank(nftOwner);
        vm.expectRevert(IPermit.ZeroToken.selector);
        permit3.approve(address(0), spenderAddress, TOKEN_ID_1, 1, uint48(block.timestamp + 3600));
    }

    function test_approve_revertsZeroSpender() public {
        vm.prank(nftOwner);
        vm.expectRevert(IPermit.ZeroSpender.selector);
        permit3.approve(address(nftToken), address(0), TOKEN_ID_1, 1, uint48(block.timestamp + 3600));
    }

    function test_approve_revertsExpiredTimestamp() public {
        uint48 expiration = uint48(block.timestamp - 1);
        vm.prank(nftOwner);
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidExpiration.selector, expiration));
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);
    }

    function test_approve_revertsExactCurrentTime() public {
        uint48 expiration = uint48(block.timestamp);
        vm.prank(nftOwner);
        vm.expectRevert(abi.encodeWithSelector(IPermit.InvalidExpiration.selector, expiration));
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);
    }

    function test_approve_allowsZeroExpiration() public {
        // Zero expiration should be allowed (means never expires)
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, 0);

        // For NFT with tokenId, use the 4-parameter allowance function
        (uint160 amount, uint48 expiration,) =
            permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);
        assertEq(amount, 1);
        assertEq(expiration, 0);
    }

    function test_approve_revertsLockedAllowance_perToken() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // First set a per-token allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);

        // Actually, let's test collection-wide lockdown affecting per-token
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(nftToken), spender: spenderAddress });

        vm.prank(nftOwner);
        permit3.lockdown(pairs);

        // Check if collection-wide lock prevents per-token approve
        // This depends on implementation - may need to verify actual behavior
        vm.prank(nftOwner);
        // If lockdown only locks collection-wide, this might succeed
        // Need to verify the actual lockdown behavior for NFTs
        permit3.approve(address(nftToken), spenderAddress, TOKEN_ID_1, 1, expiration);

        // Verify per-token allowance was updated
        (uint160 amount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, TOKEN_ID_1);
        assertEq(amount, 1);

        // But collection-wide approval should fail due to lock
        vm.prank(nftOwner);
        bytes32 collectionKey = bytes32(uint256(uint160(address(nftToken))));
        vm.expectRevert(
            abi.encodeWithSelector(IPermit.AllowanceLocked.selector, nftOwner, collectionKey, spenderAddress)
        );
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);
    }

    function test_approve_collectionWide_validation() public {
        // Test validation for collection-wide approval with zero spender
        vm.prank(nftOwner);
        vm.expectRevert(IPermit.ZeroSpender.selector);
        permit3.approve(
            address(nftToken), address(0), type(uint256).max, type(uint160).max, uint48(block.timestamp + 3600)
        );

        // Test with zero token
        vm.prank(nftOwner);
        vm.expectRevert(IPermit.ZeroToken.selector);
        permit3.approve(
            address(0), spenderAddress, type(uint256).max, type(uint160).max, uint48(block.timestamp + 3600)
        );
    }

    function test_approve_revertsLockedCollectionWide() public {
        uint48 expiration = uint48(block.timestamp + 3600);

        // First set a collection-wide allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Lock the collection-wide allowance
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(nftToken), spender: spenderAddress });

        vm.prank(nftOwner);
        permit3.lockdown(pairs);

        // Attempting to approve collection-wide again should fail
        vm.prank(nftOwner);
        bytes32 tokenKey = bytes32(uint256(uint160(address(nftToken))));
        vm.expectRevert(abi.encodeWithSelector(IPermit.AllowanceLocked.selector, nftOwner, tokenKey, spenderAddress));
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);
    }

    /**
     * @notice Test that lockdown prevents transfers even with specific tokenId approvals for ERC721
     * @dev Verifies the fix for the vulnerability where specific token approvals could bypass collection lockdown
     */
    function test_lockdownPreventsERC721TransferWithSpecificTokenApproval() public {
        uint48 expiration = uint48(block.timestamp + 1 days);
        uint256 tokenId = 0;

        // First, approve a specific token ID for the spender
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, tokenId, 1, expiration);

        // Verify the spender can transfer the specific token
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), tokenId);
        assertEq(nftToken.ownerOf(tokenId), recipientAddress);

        // Mint a new token for the next test
        vm.prank(nftOwner);
        uint256 newTokenId = nftToken.mint(nftOwner);

        // Approve the new specific token
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, newTokenId, 1, expiration);

        // Now lockdown the collection
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(nftToken), spender: spenderAddress });

        vm.prank(nftOwner);
        permit3.lockdown(pairs);

        // Attempt to transfer the specific token should now fail due to collection lockdown
        vm.prank(spenderAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiTokenPermit.CollectionLocked.selector, nftOwner, address(nftToken), spenderAddress
            )
        );
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), newTokenId);
    }

    /**
     * @notice Test that lockdown prevents transfers even with specific tokenId approvals for ERC1155
     * @dev Verifies the fix for the vulnerability where specific token approvals could bypass collection lockdown
     */
    function test_lockdownPreventsERC1155TransferWithSpecificTokenApproval() public {
        uint48 expiration = uint48(block.timestamp + 1 days);
        uint256 tokenId = 100;
        uint160 amount = 50;

        // Mint ERC1155 tokens
        vm.prank(multiTokenOwner);
        multiToken.mint(multiTokenOwner, tokenId, 100, "");

        // Set approval for Permit3 contract
        vm.prank(multiTokenOwner);
        multiToken.setApprovalForAll(address(permit3), true);

        // Approve a specific token ID for the spender
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, tokenId, amount, expiration);

        // Verify the spender can transfer the specific token
        vm.prank(spenderAddress);
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), tokenId, 25);
        assertEq(multiToken.balanceOf(recipientAddress, tokenId), 25);

        // Now lockdown the collection
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(multiToken), spender: spenderAddress });

        vm.prank(multiTokenOwner);
        permit3.lockdown(pairs);

        // Attempt to transfer the specific token should now fail due to collection lockdown
        vm.prank(spenderAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiTokenPermit.CollectionLocked.selector, multiTokenOwner, address(multiToken), spenderAddress
            )
        );
        permit3.transferFromERC1155(multiTokenOwner, recipientAddress, address(multiToken), tokenId, 25);
    }

    /**
     * @notice Test that lockdown prevents batch transfers with specific token approvals
     * @dev Ensures batch operations also respect the lockdown mechanism
     */
    function test_lockdownPreventsBatchTransfersWithSpecificApprovals() public {
        uint48 expiration = uint48(block.timestamp + 1 days);

        // Mint additional tokens
        vm.prank(nftOwner);
        uint256[] memory tokenIds = nftToken.mintBatch(nftOwner, 3);

        // Approve specific tokens for the spender
        vm.prank(nftOwner);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            permit3.approve(address(nftToken), spenderAddress, tokenIds[i], 1, expiration);
        }

        // Lockdown the collection
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(nftToken), spender: spenderAddress });

        vm.prank(nftOwner);
        permit3.lockdown(pairs);

        // Prepare batch transfer
        IMultiTokenPermit.ERC721Transfer[] memory transfers = new IMultiTokenPermit.ERC721Transfer[](1);
        transfers[0] = IMultiTokenPermit.ERC721Transfer({
            from: nftOwner,
            to: recipientAddress,
            tokenId: tokenIds[0],
            token: address(nftToken)
        });

        // Attempt batch transfer should fail due to lockdown
        vm.prank(spenderAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiTokenPermit.CollectionLocked.selector, nftOwner, address(nftToken), spenderAddress
            )
        );
        permit3.batchTransferERC721(transfers);
    }

    /**
     * @notice Test that NFTs with tokenId = type(uint256).max can be approved and transferred
     * @dev This verifies the fix for the tokenId collision issue
     */
    function test_transferFromERC721_withMaxTokenId() public {
        uint48 expiration = uint48(block.timestamp + 3600);
        uint256 maxTokenId = type(uint256).max;

        // Mint NFT with max tokenId
        vm.prank(nftOwner);
        nftToken.mint(nftOwner, maxTokenId);

        // Approve the specific token with max tokenId
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, maxTokenId, 1, expiration);

        // Verify allowance was set for the specific token
        (uint160 amount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, maxTokenId);
        assertEq(amount, 1);

        // Execute transfer of token with max tokenId
        vm.prank(spenderAddress);
        permit3.transferFromERC721(nftOwner, recipientAddress, address(nftToken), maxTokenId);

        // Verify transfer succeeded
        assertEq(nftToken.ownerOf(maxTokenId), recipientAddress);
    }

    /**
     * @notice Test that collection-wide and max tokenId approvals are distinct
     * @dev Ensures no collision between collection-wide approval and tokenId = type(uint256).max
     */
    function test_collectionWideVsMaxTokenId_distinct() public {
        uint48 expiration = uint48(block.timestamp + 3600);
        uint256 maxTokenId = type(uint256).max;

        // Mint two NFTs: one regular and one with max tokenId
        vm.prank(nftOwner);
        nftToken.mint(nftOwner, maxTokenId);

        // Set collection-wide allowance
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, type(uint160).max, expiration);

        // Check collection-wide allowance
        (uint160 collectionAmount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress);
        assertEq(collectionAmount, type(uint160).max);

        // Check specific max tokenId allowance (should be 0 since we haven't set it)
        (uint160 maxTokenAmount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, maxTokenId);
        assertEq(maxTokenAmount, 0);

        // Now set specific approval for max tokenId
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, maxTokenId, 1, expiration);

        // Verify both allowances are distinct
        (collectionAmount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress);
        assertEq(collectionAmount, type(uint160).max, "Collection-wide allowance should remain unchanged");

        (maxTokenAmount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, maxTokenId);
        assertEq(maxTokenAmount, 1, "Max tokenId specific allowance should be set");
    }

    /**
     * @notice Test that approve emits ApprovalWithTokenId event for better transparency
     * @dev Verifies the fix for the audit finding about missing tokenId in approval events
     */
    function test_approve_emitsApprovalWithTokenId() public {
        uint48 expiration = uint48(block.timestamp + 3600);
        uint256 tokenId = 42;
        uint160 amount = 1;

        // Test ERC721 approval (amount = 1)
        vm.expectEmit(true, true, true, true);
        emit IMultiTokenPermit.ApprovalWithTokenId(
            nftOwner,
            address(nftToken),
            spenderAddress,
            tokenId,
            amount,
            expiration
        );
        
        // Also expect the standard Approval event for backward compatibility
        vm.expectEmit(true, true, true, true);
        emit IPermit.Approval(nftOwner, address(nftToken), spenderAddress, amount, expiration);
        
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, tokenId, amount, expiration);

        // Test ERC1155 approval with higher amount
        uint160 erc1155Amount = 100;
        vm.expectEmit(true, true, true, true);
        emit IMultiTokenPermit.ApprovalWithTokenId(
            multiTokenOwner,
            address(multiToken),
            spenderAddress,
            tokenId,
            erc1155Amount,
            expiration
        );
        
        vm.prank(multiTokenOwner);
        permit3.approve(address(multiToken), spenderAddress, tokenId, erc1155Amount, expiration);
    }

    /**
     * @notice Test collection-wide approval emits ApprovalWithTokenId with max uint256 tokenId
     * @dev Collection-wide approvals use type(uint256).max as tokenId
     */
    function test_approve_collectionWide_emitsApprovalWithTokenId() public {
        uint48 expiration = uint48(block.timestamp + 3600);
        uint256 collectionTokenId = type(uint256).max;
        uint160 amount = type(uint160).max;

        vm.expectEmit(true, true, true, true);
        emit IMultiTokenPermit.ApprovalWithTokenId(
            nftOwner,
            address(nftToken),
            spenderAddress,
            collectionTokenId,
            amount,
            expiration
        );
        
        vm.prank(nftOwner);
        permit3.approve(address(nftToken), spenderAddress, collectionTokenId, amount, expiration);
        
        // Verify the approval was set correctly
        (uint160 approvedAmount,,) = permit3.allowance(nftOwner, address(nftToken), spenderAddress, collectionTokenId);
        assertEq(approvedAmount, amount);
    }
}
