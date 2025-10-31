// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/Permit3.sol";
import "../src/interfaces/INonceManager.sol";
import "./utils/TestBase.sol";

/**
 * @title TreeCancellationTest
 * @notice Integration tests for tree-based nonce cancellation
 * @dev Tests the complete flow: NonceNode construction -> signing -> invalidateNonces() execution
 */
contract TreeCancellationTest is TestBase {
    // Events (from INonceManager)
    event NonceInvalidated(address indexed owner, bytes32 indexed salt);

    // Test nonces
    bytes32 nonce1 = bytes32(uint256(0x1111));
    bytes32 nonce2 = bytes32(uint256(0x2222));
    bytes32 nonce3 = bytes32(uint256(0x3333));
    bytes32 nonce4 = bytes32(uint256(0x4444));
    bytes32 nonce5 = bytes32(uint256(0x5555));
    bytes32 nonce6 = bytes32(uint256(0x6666));

    function setUp() public override {
        super.setUp();
    }

    // ============================================
    // Basic Cancellation Tests
    // ============================================

    function test_cancelSingleNonce() public {
        // Test cancelling a single nonce using simple signed invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify: Nonce is not used initially
        assertFalse(permit3.isNonceUsed(owner, nonce1), "Nonce should not be used initially");

        // Execute: Call simple invalidateNonces
        vm.expectEmit(true, true, false, false);
        emit NonceInvalidated(owner, nonce1);
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify: Nonce is marked as used
        assertTrue(permit3.isNonceUsed(owner, nonce1), "Nonce should be marked as used");
    }

    function test_cancelTwoNonces() public {
        // Test cancelling two nonces using simple signed invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce2;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonces are not used yet
        assertFalse(permit3.isNonceUsed(owner, nonce1), "Nonce1 should not be used initially");
        assertFalse(permit3.isNonceUsed(owner, nonce2), "Nonce2 should not be used initially");

        // Execute cancellation
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify both nonces are now used
        assertTrue(permit3.isNonceUsed(owner, nonce1), "Nonce1 should be marked as used");
        assertTrue(permit3.isNonceUsed(owner, nonce2), "Nonce2 should be marked as used");
    }

    function test_cancelMultipleNoncesInOneCall() public {
        // Test cancelling multiple nonces using simple signed invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = nonce1;
        salts[1] = nonce2;
        salts[2] = nonce3;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonces are not used yet
        assertFalse(permit3.isNonceUsed(owner, nonce1));
        assertFalse(permit3.isNonceUsed(owner, nonce2));
        assertFalse(permit3.isNonceUsed(owner, nonce3));

        // Execute cancellation
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all are now used
        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
    }

    function test_cancelMultipleNoncesWithProof() public {
        // Test cancelling multiple nonces using simple signed invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](4);
        salts[0] = nonce1;
        salts[1] = nonce2;
        salts[2] = nonce3;
        salts[3] = nonce4;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute cancellation
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify all are used
        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
        assertTrue(permit3.isNonceUsed(owner, nonce4));
    }

    // ============================================
    // Tree Structure Tests
    // ============================================

    function test_cancelNonces_nestedStructure() public {
        // Test with nested NonceNode structure
        // Tree: NonceNode { nodes: [NonceNode{nonces:[nonce1,nonce2]}], nonces: [nonce3] }

        // Build inner node
        bytes32[] memory innerNonces = new bytes32[](2);
        innerNonces[0] = nonce1;
        innerNonces[1] = nonce2;
        INonceManager.NonceNode memory innerNode = _buildNonceNodeWithNonces(innerNonces);

        // Build outer node
        INonceManager.NonceNode memory outerNode;
        outerNode.nodes = new INonceManager.NonceNode[](1);
        outerNode.nodes[0] = innerNode;
        outerNode.nonces = new INonceManager.NoncesToInvalidate[](1);
        outerNode.nonces[0] =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        outerNode.nonces[0].salts[0] = nonce3;

        // Hash the tree
        bytes32 treeHash = _hashNonceNode(outerNode);

        // Sign the tree
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signNonceTreeCancellation(owner, deadline, treeHash);

        // Cancel nonce3 (the leaf nonce)
        bytes32[] memory currentNonces = new bytes32[](1);
        currentNonces[0] = nonce3;

        // Proof: hash of inner node
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _hashNonceNode(innerNode);

        // proofStructure: proof[0] is a Node (bit = 1)
        bytes32 proofStructure = bytes32(uint256(1) << 247);

        // Execute cancellation
        permit3.invalidateNonces(
            INonceManager.NonceTree(
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: currentNonces }),
                proofStructure,
                proof
            ),
            INonceManager.NonceSignature(owner, deadline, signature)
        );

        // Verify only nonce3 is used
        assertFalse(permit3.isNonceUsed(owner, nonce1));
        assertFalse(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
    }

    function test_cancelNonces_deepNesting() public {
        // Test with 3-level deep NonceNode tree
        // Level 3: NonceNode{nonces:[nonce1]}
        // Level 2: NonceNode{nodes:[level3], nonces:[nonce2]}
        // Level 1: NonceNode{nodes:[level2], nonces:[nonce3]}

        // Build level 3
        bytes32[] memory level3Nonces = new bytes32[](1);
        level3Nonces[0] = nonce1;
        INonceManager.NonceNode memory level3 = _buildNonceNodeWithNonces(level3Nonces);

        // Build level 2
        INonceManager.NonceNode memory level2;
        level2.nodes = new INonceManager.NonceNode[](1);
        level2.nodes[0] = level3;
        level2.nonces = new INonceManager.NoncesToInvalidate[](1);
        level2.nonces[0] = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        level2.nonces[0].salts[0] = nonce2;

        // Build level 1 (root)
        INonceManager.NonceNode memory root;
        root.nodes = new INonceManager.NonceNode[](1);
        root.nodes[0] = level2;
        root.nonces = new INonceManager.NoncesToInvalidate[](1);
        root.nonces[0] = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        root.nonces[0].salts[0] = nonce3;

        // Hash the tree
        bytes32 treeHash = _hashNonceNode(root);

        // Sign the tree
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signNonceTreeCancellation(owner, deadline, treeHash);

        // Cancel nonce3
        bytes32[] memory currentNonces = new bytes32[](1);
        currentNonces[0] = nonce3;

        // Proof: hash of level2
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _hashNonceNode(level2);

        // proofStructure: proof[0] is a Node
        bytes32 proofStructure = bytes32(uint256(1) << 247);

        // Execute cancellation
        permit3.invalidateNonces(
            INonceManager.NonceTree(
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: currentNonces }),
                proofStructure,
                proof
            ),
            INonceManager.NonceSignature(owner, deadline, signature)
        );

        // Verify only nonce3 is used
        assertFalse(permit3.isNonceUsed(owner, nonce1));
        assertFalse(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
    }

    function test_cancelNonces_complexTree_invalidStructure_reverts() public {
        // INVALID STRUCTURE TEST: { nodes: [node1, node2], nonces: [nonce5] }
        // This has 3 children (2 nodes + 1 nonce), violating the binary tree constraint
        //
        // TreeNodeLib only supports BINARY combinations:
        //   - combineLeafAndLeaf(leaf1, leaf2)      - 2 leaves
        //   - combineNodeAndNode(node1, node2)      - 2 nodes
        //   - combineNodeAndLeaf(node, leaf)        - 1 node + 1 leaf
        //
        // There is NO function for: 2 nodes + 1 nonce
        // The reconstruction will produce a DIFFERENT hash than what was signed → REVERT

        // Build node1: [nonce1, nonce2]
        bytes32[] memory node1Nonces = new bytes32[](2);
        node1Nonces[0] = nonce1;
        node1Nonces[1] = nonce2;
        INonceManager.NonceNode memory node1 = _buildNonceNodeWithNonces(node1Nonces);

        // Build node2: [nonce3, nonce4]
        bytes32[] memory node2Nonces = new bytes32[](2);
        node2Nonces[0] = nonce3;
        node2Nonces[1] = nonce4;
        INonceManager.NonceNode memory node2 = _buildNonceNodeWithNonces(node2Nonces);

        // Build INVALID root: 2 nodes + 1 nonce = 3 children
        INonceManager.NonceNode memory root;
        root.nodes = new INonceManager.NonceNode[](2);
        root.nodes[0] = node1;
        root.nodes[1] = node2;
        root.nonces = new INonceManager.NoncesToInvalidate[](1);
        root.nonces[0] = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        root.nonces[0].salts[0] = nonce5;

        // Hash and sign the invalid tree
        bytes32 treeHash = _hashNonceNode(root);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signNonceTreeCancellation(owner, deadline, treeHash);

        // Try to cancel nonce5 with proof [node1, node2]
        bytes32[] memory currentNonces = new bytes32[](1);
        currentNonces[0] = nonce5;

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = _hashNonceNode(node1);
        proof[1] = _hashNonceNode(node2);

        // proofStructure: both proof elements are Nodes (bits 247 and 246 set to 1)
        bytes32 proofStructure = bytes32(uint256(1) << 247 | uint256(1) << 246);

        // Should REVERT: reconstruction produces different hash → signature verification fails
        // Expected error: INonceManager.InvalidSignature(recoveredAddress)
        // Note: Can't predict exact recovered address from invalid signature
        vm.expectRevert();
        permit3.invalidateNonces(
            INonceManager.NonceTree(
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: currentNonces }),
                proofStructure,
                proof
            ),
            INonceManager.NonceSignature(owner, deadline, signature)
        );
    }

    function test_cancelNonces_complexTree_RESTRUCTURED() public {
        // VALID ALTERNATIVE: Restructure to respect binary constraint
        // Original intent: Tree with 5 nonces (nonce1-5) where we can cancel nonce5 separately
        //
        // INVALID structure (3 children at root):
        //   Root { nodes: [node1, node2], nonces: [nonce5] }
        //
        // VALID structure (2 children at root):
        //   Root { nodes: [nodesBranch], nonces: [nonce5] }
        //     where nodesBranch = { nodes: [node1, node2], nonces: [] }
        //
        // This is a binary tree:
        //   - Root has 2 children: 1 node + 1 nonce ✓
        //   - nodesBranch has 2 children: 2 nodes ✓
        //   - node1 has 2 children: 2 nonces ✓
        //   - node2 has 2 children: 2 nonces ✓

        // Build node1: [nonce1, nonce2]
        bytes32[] memory node1Nonces = new bytes32[](2);
        node1Nonces[0] = nonce1;
        node1Nonces[1] = nonce2;
        INonceManager.NonceNode memory node1 = _buildNonceNodeWithNonces(node1Nonces);

        // Build node2: [nonce3, nonce4]
        bytes32[] memory node2Nonces = new bytes32[](2);
        node2Nonces[0] = nonce3;
        node2Nonces[1] = nonce4;
        INonceManager.NonceNode memory node2 = _buildNonceNodeWithNonces(node2Nonces);

        // Build nodesBranch: wraps node1 and node2
        INonceManager.NonceNode memory nodesBranch;
        nodesBranch.nodes = new INonceManager.NonceNode[](2);
        nodesBranch.nodes[0] = node1;
        nodesBranch.nodes[1] = node2;
        nodesBranch.nonces = new INonceManager.NoncesToInvalidate[](0); // No nonces at this level

        // Build root: 1 node + 1 nonce (binary!)
        INonceManager.NonceNode memory root;
        root.nodes = new INonceManager.NonceNode[](1);
        root.nodes[0] = nodesBranch;
        root.nonces = new INonceManager.NoncesToInvalidate[](1);
        root.nonces[0] = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        root.nonces[0].salts[0] = nonce5;

        // Hash the tree
        bytes32 treeHash = _hashNonceNode(root);

        // Sign the tree
        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes memory signature = _signNonceTreeCancellation(owner, deadline, treeHash);

        // Cancel nonce5 (the single nonce at root level)
        bytes32[] memory currentNonces = new bytes32[](1);
        currentNonces[0] = nonce5;

        // Proof: hash of nodesBranch (sibling of nonce5)
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _hashNonceNode(nodesBranch);

        // proofStructure: proof[0] is a Node (bit = 1)
        bytes32 proofStructure = bytes32(uint256(1) << 247);

        // Execute cancellation
        permit3.invalidateNonces(
            INonceManager.NonceTree(
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: currentNonces }),
                proofStructure,
                proof
            ),
            INonceManager.NonceSignature(owner, deadline, signature)
        );

        // Verify only nonce5 is used (the others should remain untouched)
        assertFalse(permit3.isNonceUsed(owner, nonce1), "nonce1 should NOT be used");
        assertFalse(permit3.isNonceUsed(owner, nonce2), "nonce2 should NOT be used");
        assertFalse(permit3.isNonceUsed(owner, nonce3), "nonce3 should NOT be used");
        assertFalse(permit3.isNonceUsed(owner, nonce4), "nonce4 should NOT be used");
        assertTrue(permit3.isNonceUsed(owner, nonce5), "nonce5 should be marked as used");
    }

    // ============================================
    // Signature Verification Tests
    // ============================================

    function test_cancelNonces_validSignature() public {
        // Test with properly signed simple invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        assertTrue(permit3.isNonceUsed(owner, nonce1));
    }

    function test_cancelNonces_invalidSignature() public {
        // Test with wrong signature - should revert

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create wrong signature (sign different data)
        INonceManager.NoncesToInvalidate memory wrongInvalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: new bytes32[](1) });
        wrongInvalidations.salts[0] = keccak256("wrong");
        bytes32 wrongStructHash = _getInvalidationStructHash(owner, deadline, wrongInvalidations);
        bytes32 wrongDigest = exposed_hashTypedDataV4(wrongStructHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, wrongDigest);
        bytes memory wrongSignature = abi.encodePacked(r, s, v);

        // Should REVERT: signature is for wrong data → signature verification fails
        vm.expectRevert();
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, wrongSignature));
    }

    function test_cancelNonces_expiredDeadline() public {
        // Test with deadline in the past

        uint48 deadline = uint48(block.timestamp - 1); // Expired
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert with SignatureExpired
        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, deadline, uint48(block.timestamp))
        );
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));
    }

    function test_cancelNonces_wrongSigner() public {
        // Test with signature from wrong account

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Sign with different private key
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x9999, digest); // Wrong key
        bytes memory wrongSignature = abi.encodePacked(r, s, v);

        // Should REVERT: signature from wrong private key → recovered signer != owner
        vm.expectRevert();
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, wrongSignature));
    }

    // ============================================
    // Proof Verification Tests
    // ============================================

    function test_cancelNonces_emptyProof() public {
        // Test with single nonce using simple signed invalidation
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        assertTrue(permit3.isNonceUsed(owner, nonce1));
    }

    function test_cancelNonces_validProof() public {
        // Test with valid signature for 2-nonce scenario
        // Single-chain scenario should use the simple invalidateNonces function

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce2;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
    }

    function test_cancelNonces_invalidProof() public {
        // Test with tampered data - should fail signature verification

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce2;

        // Sign valid data
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Try to cancel different nonces with the signature
        bytes32[] memory wrongSalts = new bytes32[](2);
        wrongSalts[0] = nonce1;
        wrongSalts[1] = nonce3; // Different nonce!

        // Should REVERT: wrong data → signature verification fails
        vm.expectRevert();
        permit3.invalidateNonces(wrongSalts, INonceManager.NonceSignature(owner, deadline, signature));
    }

    function test_cancelNonces_wrongTreeStructure() public {
        // Test that simple signed invalidation works correctly for single chain
        // This replaces the tree structure test with a proper single-chain test

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce2;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
    }

    // ============================================
    // Nonce Invalidation Tests
    // ============================================

    function test_cancelNonces_marksNoncesAsUsed() public {
        // Verify nonces are actually marked as used after cancellation

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = nonce1;
        salts[1] = nonce2;
        salts[2] = nonce3;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify all are NOT used initially
        assertFalse(permit3.isNonceUsed(owner, nonce1));
        assertFalse(permit3.isNonceUsed(owner, nonce2));
        assertFalse(permit3.isNonceUsed(owner, nonce3));

        // Cancel all
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify ALL are marked as used
        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
    }

    function test_cancelNonces_emitsEvents() public {
        // Verify NonceInvalidated events are emitted

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce2;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect events for both nonces
        vm.expectEmit(true, true, false, false);
        emit NonceInvalidated(owner, nonce1);
        vm.expectEmit(true, true, false, false);
        emit NonceInvalidated(owner, nonce2);

        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));
    }

    function test_cancelNonces_cannotReuseCancelledNonce() public {
        // After cancellation, using the nonce should fail

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cancel the nonce
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Try to use the cancelled nonce in a permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();
        bytes memory permitSignature = _signPermit(chainPermits, deadline, uint48(block.timestamp), nonce1);

        // Should revert because nonce is already used
        vm.expectRevert(abi.encodeWithSelector(INonceManager.NonceAlreadyUsed.selector, owner, nonce1));
        permit3.permit(
            chainPermits.permits,
            IPermit3.Signature({
                owner: owner,
                salt: nonce1,
                deadline: deadline,
                timestamp: uint48(block.timestamp),
                signature: permitSignature
            })
        );
    }

    function test_cancelNonces_multipleNoncesAllMarked() public {
        // When cancelling multiple nonces, verify ALL are marked

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](5);
        salts[0] = nonce1;
        salts[1] = nonce2;
        salts[2] = nonce3;
        salts[3] = nonce4;
        salts[4] = nonce5;

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cancel all 5
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        // Verify ALL are marked
        assertTrue(permit3.isNonceUsed(owner, nonce1));
        assertTrue(permit3.isNonceUsed(owner, nonce2));
        assertTrue(permit3.isNonceUsed(owner, nonce3));
        assertTrue(permit3.isNonceUsed(owner, nonce4));
        assertTrue(permit3.isNonceUsed(owner, nonce5));
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_cancelNonces_emptyArray() public {
        // Test with empty nonces array - should revert

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](0); // Empty

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should REVERT: empty nonces array is invalid
        vm.expectRevert();
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));
    }

    function test_cancelNonces_duplicateNonces() public {
        // Test with same nonce appearing twice in salts

        uint48 deadline = uint48(block.timestamp + 1 hours);
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = nonce1;
        salts[1] = nonce1; // Duplicate

        // Create signature using simple signed invalidation
        INonceManager.NoncesToInvalidate memory invalidations =
            INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
        bytes32 digest = exposed_hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed (just marks nonce1 as used)
        permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));

        assertTrue(permit3.isNonceUsed(owner, nonce1));
    }

    function test_cancelNonces_alreadyCancelled() public {
        // Test cancelling a nonce that's already used

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = nonce1;

        // Cancel once
        {
            uint48 deadline = uint48(block.timestamp + 1 hours);
            INonceManager.NoncesToInvalidate memory invalidations =
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
            bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
            bytes32 digest = exposed_hashTypedDataV4(structHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
            bytes memory signature = abi.encodePacked(r, s, v);

            permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));
            assertTrue(permit3.isNonceUsed(owner, nonce1));
        }

        // Try to cancel again - should succeed (idempotent operation)
        {
            uint48 deadline2 = uint48(block.timestamp + 2 hours);
            INonceManager.NoncesToInvalidate memory invalidations2 =
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
            bytes32 structHash2 = _getInvalidationStructHash(owner, deadline2, invalidations2);
            bytes32 digest2 = exposed_hashTypedDataV4(structHash2);
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(ownerPrivateKey, digest2);
            bytes memory signature2 = abi.encodePacked(r2, s2, v2);

            permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline2, signature2));
        }

        // Still marked as used
        assertTrue(permit3.isNonceUsed(owner, nonce1));
    }

    // ============================================
    // Comparison Tests (Tree vs Individual)
    // ============================================

    function test_cancelNonces_equivalentToIndividual() public {
        // Verify signed cancellation produces same result as individual calls

        bytes32 testNonce1 = bytes32(uint256(0x7777));
        bytes32 testNonce2 = bytes32(uint256(0x8888));

        // Account 1 (owner): Use signed invalidation
        {
            uint48 deadline = uint48(block.timestamp + 1 hours);
            bytes32[] memory salts = new bytes32[](2);
            salts[0] = testNonce1;
            salts[1] = testNonce2;

            INonceManager.NoncesToInvalidate memory invalidations =
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
            bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
            bytes32 digest = exposed_hashTypedDataV4(structHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
            bytes memory signature = abi.encodePacked(r, s, v);

            permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, signature));
        }

        // Account 2: Use individual invalidateNonces calls
        address account2 = makeAddr("account2");
        vm.startPrank(account2);
        bytes32[] memory individualSalts = new bytes32[](1);
        individualSalts[0] = testNonce1;
        permit3.invalidateNonces(individualSalts);
        individualSalts[0] = testNonce2;
        permit3.invalidateNonces(individualSalts);
        vm.stopPrank();

        // Both should have same result
        assertTrue(permit3.isNonceUsed(owner, testNonce1));
        assertTrue(permit3.isNonceUsed(owner, testNonce2));
        assertTrue(permit3.isNonceUsed(account2, testNonce1));
        assertTrue(permit3.isNonceUsed(account2, testNonce2));
    }

    function test_cancelNonces_gasComparison() public {
        // Measure gas for signed vs direct cancellations
        bytes32 n1 = bytes32(uint256(0x9999));
        bytes32 n2 = bytes32(uint256(0xaaaa));
        bytes32 n3 = bytes32(uint256(0xbbbb));

        // Signed cancellation
        {
            uint48 deadline = uint48(block.timestamp + 1 hours);
            bytes32[] memory salts = new bytes32[](3);
            salts[0] = n1;
            salts[1] = n2;
            salts[2] = n3;

            INonceManager.NoncesToInvalidate memory invalidations =
                INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
            bytes32 structHash = _getInvalidationStructHash(owner, deadline, invalidations);
            bytes32 digest = exposed_hashTypedDataV4(structHash);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
            bytes memory sig = abi.encodePacked(r, s, v);

            uint256 gasBefore = gasleft();
            permit3.invalidateNonces(salts, INonceManager.NonceSignature(owner, deadline, sig));
            emit log_named_uint("Gas: signed cancellation (3 nonces)", gasBefore - gasleft());
        }

        // Direct invalidation comparison
        {
            address account2 = makeAddr("account3");
            vm.startPrank(account2);

            bytes32[] memory salts = new bytes32[](3);
            salts[0] = n1;
            salts[1] = n2;
            salts[2] = n3;

            uint256 gasBefore = gasleft();
            permit3.invalidateNonces(salts);
            emit log_named_uint("Gas: direct invalidation (3 nonces)", gasBefore - gasleft());

            vm.stopPrank();
        }

        // Verify both worked
        assertTrue(permit3.isNonceUsed(owner, n1));
    }
}
