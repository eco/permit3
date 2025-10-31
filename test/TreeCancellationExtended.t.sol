// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Permit3.sol";
import "../src/interfaces/INonceManager.sol";
import "./utils/TestBase.sol";

/**
 * @title TreeCancellationExtendedTest
 * @notice Extended tests for simple signed nonce invalidation with multiple nonces
 * @dev These tests cover various scenarios for single-chain nonce invalidation using invalidateNonces(owner, deadline,
 * salts[], signature)
 */
contract TreeCancellationExtendedTest is TestBase {
    // Test nonces (using unique values to avoid conflicts)
    bytes32 constant N1 = bytes32(uint256(0xA001));
    bytes32 constant N2 = bytes32(uint256(0xA002));
    bytes32 constant N3 = bytes32(uint256(0xA003));
    bytes32 constant N4 = bytes32(uint256(0xA004));
    bytes32 constant N5 = bytes32(uint256(0xA005));
    bytes32 constant N6 = bytes32(uint256(0xA006));

    function setUp() public override {
        super.setUp();
    }

    // ============================================
    // A. Unbalanced Tree Test
    // ============================================

    function test_cancelNonces_unbalancedTree() public {
        // Test simple signed nonce invalidation with multiple nonces
        // We sign to invalidate N1 and N2, but only actually invalidate N1
        // This tests that the signature covers all nonces but only specified ones are marked

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Build salts array - sign for both N1 and N2
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = N1;
        salts[1] = N2;

        // Create the invalidation struct
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Sign the invalidation
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Invalidate all signed nonces
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all nonces in the signature are cancelled
        assertTrue(permit3.isNonceUsed(owner, N1));
        assertTrue(permit3.isNonceUsed(owner, N2));
    }

    // ============================================
    // B. Multiple Nonces at Root Test
    // ============================================

    // NOTE: Restructured to be a valid binary tree
    // Original structure had 1 node + 3 nonces = 4 children (INVALID)
    // Restructured to 1 node + 1 nonce = 2 children (VALID)
    // Tests canceling a nonce from root level when root has both nested nodes and direct nonces
    function test_cancelNonces_nonceAtRootWithNestedNode() public {
        // Test simple signed nonce invalidation with three nonces (N1, N2, N3)
        // Sign for all three, invalidate all three

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Build salts array - sign for N1, N2, and N3
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = N1;
        salts[1] = N2;
        salts[2] = N3;

        // Create the invalidation struct
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Sign the invalidation
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Invalidate all signed nonces
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all nonces are cancelled
        assertTrue(permit3.isNonceUsed(owner, N1));
        assertTrue(permit3.isNonceUsed(owner, N2));
        assertTrue(permit3.isNonceUsed(owner, N3));
    }

    // ============================================
    // C. Cancel From Middle Level Test
    // ============================================

    function test_cancelNonces_fromMiddleLevel() public {
        // Test simple signed nonce invalidation with three nonces (N1, N2, N3)
        // Sign for all three, invalidate all three

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Build salts array - sign for N1, N2, and N3
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = N1;
        salts[1] = N2;
        salts[2] = N3;

        // Create the invalidation struct
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Sign the invalidation
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Invalidate all signed nonces
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all nonces are cancelled
        assertTrue(permit3.isNonceUsed(owner, N1));
        assertTrue(permit3.isNonceUsed(owner, N2));
        assertTrue(permit3.isNonceUsed(owner, N3));
    }

    // ============================================
    // D. Four-Level Deep Nesting Test
    // ============================================

    function test_cancelNonces_fourLevelDeepNesting() public {
        // Test simple signed nonce invalidation with two nonces (N1, N2)
        // Sign for both, invalidate both

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Build salts array - sign for N1 and N2
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = N1;
        salts[1] = N2;

        // Create the invalidation struct
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Sign the invalidation
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Invalidate all signed nonces
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all nonces are cancelled
        assertTrue(permit3.isNonceUsed(owner, N1));
        assertTrue(permit3.isNonceUsed(owner, N2));
    }

    // ============================================
    // E. Cancel Multiple Nonces Simultaneously Test
    // ============================================

    // NOTE: This test is REMOVED - duplicate functionality
    // The functionality of canceling multiple nonces from the same level is already tested in:
    // - TreeCancellation.t.sol::test_cancelMultipleNoncesInOneCall() (lines 99-136)
    //   Tests building a tree with 3 nonces and canceling all 3 at once
    // - TreeCancellation.t.sol::test_cancelNonces_multipleNoncesAllMarked() (lines 623-656)
    //   Tests building a tree with 5 nonces and verifying all are marked when cancelled
    //
    // The original structure with 4 nonces at one level was invalid (violated binary constraint).
    // Restructuring it to be valid (2 nonces) would provide no additional test coverage beyond
    // what already exists in TreeCancellation.t.sol.

    // ============================================
    // F. All Nodes No Direct Nonces Test
    // ============================================

    function test_cancelNonces_allNodesStructure() public {
        // Test simple signed nonce invalidation with four nonces (N1, N2, N3, N4)
        // Sign for all four, invalidate all four

        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Build salts array - sign for N1, N2, N3, and N4
        bytes32[] memory salts = new bytes32[](4);
        salts[0] = N1;
        salts[1] = N2;
        salts[2] = N3;
        salts[3] = N4;

        // Create the invalidation struct
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Sign the invalidation
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Invalidate all signed nonces
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all nonces are cancelled
        assertTrue(permit3.isNonceUsed(owner, N1));
        assertTrue(permit3.isNonceUsed(owner, N2));
        assertTrue(permit3.isNonceUsed(owner, N3));
        assertTrue(permit3.isNonceUsed(owner, N4));
    }
}
