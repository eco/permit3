// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/lib/TreeNodeLib.sol";
import "./utils/TreeNodeLibTester.sol";
import "forge-std/Test.sol";

/**
 * @title TreeNodeLibTest
 * @notice Comprehensive test suite for the generic TreeNodeLib library
 * @dev Tests the library with both PERMIT_NODE_TYPEHASH and NONCE_NODE_TYPEHASH
 *      to ensure generalization works correctly
 *
 * TEST PHILOSOPHY:
 * Unlike PermitNodeLib.t.sol and NonceNodeLib.t.sol which test specialized wrappers,
 * this file tests the GENERIC TreeNodeLib directly. The key insight is that the
 * reconstruction algorithm should work identically for any EIP-712 typehash - the
 * typehash is just a parameter that changes the output but not the algorithm behavior.
 *
 * This test suite verifies:
 * 1. TreeNodeLib works with ANY typehash (tested with two different ones)
 * 2. Sorting behavior is consistent across typehashes
 * 3. Different typehashes produce different outputs (as expected)
 * 4. Algorithm behavior is identical regardless of typehash chosen
 */
contract TreeNodeLibTest is Test {
    TreeNodeLibTester public tester;

    // Test typehashes - should produce different hashes but same algorithm behavior
    bytes32 constant PERMIT_NODE_TYPEHASH = keccak256(
        "PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)"
    );

    bytes32 constant NONCE_NODE_TYPEHASH = keccak256("NonceNode(NonceNode[] nodes,bytes32[] nonces)");

    function setUp() public {
        tester = new TreeNodeLibTester();
    }

    // ============================================
    // Category 1: Constants Verification (1 test)
    // ============================================

    function test_typehashesAreDifferent() public pure {
        assertTrue(PERMIT_NODE_TYPEHASH != NONCE_NODE_TYPEHASH, "Typehashes should be different");
    }

    // ============================================
    // Category 2: combineLeafAndLeaf Tests (12 tests)
    // ============================================

    /**
     * Test basic combination with PERMIT_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_permitTypehash_basic() public view {
        bytes32 leaf1 = bytes32(uint256(0x1111));
        bytes32 leaf2 = bytes32(uint256(0x2222));

        bytes32 result = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);

        // Result should be Node(nodes=[], leaves=[leaf1, leaf2]) with PERMIT_NODE_TYPEHASH
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leaf1, leaf2));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, keccak256(""), expectedLeavesHash));

        assertEq(result, expected, "Should create Node with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test basic combination with NONCE_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_nonceTypehash_basic() public view {
        bytes32 leaf1 = bytes32(uint256(0x1111));
        bytes32 leaf2 = bytes32(uint256(0x2222));

        bytes32 result = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);

        // Result should be Node(nodes=[], leaves=[leaf1, leaf2]) with NONCE_NODE_TYPEHASH
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leaf1, leaf2));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, keccak256(""), expectedLeavesHash));

        assertEq(result, expected, "Should create Node with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test sorting behavior with PERMIT_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_permitTypehash_sorting() public view {
        bytes32 leaf1 = bytes32(uint256(0x2222));
        bytes32 leaf2 = bytes32(uint256(0x1111));

        bytes32 result = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);

        // Should sort: smaller first (leaf2, leaf1)
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leaf2, leaf1));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, keccak256(""), expectedLeavesHash));

        assertEq(result, expected, "Should sort leaves alphabetically with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test sorting behavior with NONCE_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_nonceTypehash_sorting() public view {
        bytes32 leaf1 = bytes32(uint256(0x2222));
        bytes32 leaf2 = bytes32(uint256(0x1111));

        bytes32 result = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);

        // Should sort: smaller first (leaf2, leaf1)
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leaf2, leaf1));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, keccak256(""), expectedLeavesHash));

        assertEq(result, expected, "Should sort leaves alphabetically with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test order invariance (commutativity) with PERMIT_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_permitTypehash_orderInvariant() public view {
        bytes32 leaf1 = bytes32(uint256(0x1111));
        bytes32 leaf2 = bytes32(uint256(0x2222));

        bytes32 result1 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 result2 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf2, leaf1);

        assertEq(result1, result2, "Should be order-invariant with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test order invariance (commutativity) with NONCE_NODE_TYPEHASH
     */
    function test_combineLeafAndLeaf_nonceTypehash_orderInvariant() public view {
        bytes32 leaf1 = bytes32(uint256(0x1111));
        bytes32 leaf2 = bytes32(uint256(0x2222));

        bytes32 result1 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 result2 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf2, leaf1);

        assertEq(result1, result2, "Should be order-invariant with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test with identical leaves
     */
    function test_combineLeafAndLeaf_identicalLeaves() public view {
        bytes32 leaf = bytes32(uint256(0x1111));

        bytes32 permitResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf, leaf);
        bytes32 nonceResult = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf, leaf);

        // Should produce valid results (different for different typehashes)
        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test with zero hashes
     */
    function test_combineLeafAndLeaf_zeroHashes() public view {
        bytes32 zeroHash = bytes32(0);

        bytes32 permitResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, zeroHash, zeroHash);
        bytes32 nonceResult = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, zeroHash, zeroHash);

        // Should produce valid non-zero results
        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero even with zero inputs");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero even with zero inputs");
    }

    /**
     * Test with maximum uint256 hashes
     */
    function test_combineLeafAndLeaf_maxValues() public view {
        bytes32 maxHash = bytes32(type(uint256).max);

        bytes32 permitResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, maxHash, maxHash);
        bytes32 nonceResult = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, maxHash, maxHash);

        // Should handle max values without reverting
        assertTrue(permitResult != bytes32(0), "PERMIT result should handle max values");
        assertTrue(nonceResult != bytes32(0), "NONCE result should handle max values");
    }

    /**
     * CRITICAL TEST: Different typehashes produce different outputs for same leaves
     */
    function test_combineLeafAndLeaf_sameLeavesDifferentTypehashesProduceDifferentResults() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");

        // Combine with PermitNode typehash
        bytes32 permitRoot = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);

        // Combine with NonceNode typehash
        bytes32 nonceRoot = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);

        // Roots should be DIFFERENT (different typehashes)
        assertTrue(permitRoot != nonceRoot, "Different typehashes should produce different roots");
    }

    /**
     * CRITICAL TEST: Sorting behavior is consistent across typehashes
     */
    function test_combineLeafAndLeaf_sortingIsConsistentAcrossTypehashes() public view {
        bytes32 leaf1 = keccak256("aaa");
        bytes32 leaf2 = keccak256("zzz");

        // Both typehashes should sort the same way (commutative)
        bytes32 permitResult1 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 permitResult2 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf2, leaf1);

        bytes32 nonceResult1 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 nonceResult2 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf2, leaf1);

        // Results should be commutative for EACH typehash
        assertEq(permitResult1, permitResult2, "Permit leaf sorting failed");
        assertEq(nonceResult1, nonceResult2, "Nonce leaf sorting failed");
    }

    // ============================================
    // Category 3: combineNodeAndNode Tests (12 tests)
    // ============================================

    /**
     * Test basic combination with PERMIT_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_permitTypehash_basic() public view {
        bytes32 node1 = bytes32(uint256(0x1111));
        bytes32 node2 = bytes32(uint256(0x2222));

        bytes32 result = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);

        // Result should be Node(nodes=[node1, node2], leaves=[])
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(node1, node2));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, expectedNodesHash, keccak256("")));

        assertEq(result, expected, "Should create Node with nodes array using PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test basic combination with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_nonceTypehash_basic() public view {
        bytes32 node1 = bytes32(uint256(0x1111));
        bytes32 node2 = bytes32(uint256(0x2222));

        bytes32 result = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);

        // Result should be Node(nodes=[node1, node2], leaves=[])
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(node1, node2));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, expectedNodesHash, keccak256("")));

        assertEq(result, expected, "Should create Node with nodes array using NONCE_NODE_TYPEHASH");
    }

    /**
     * Test sorting behavior with PERMIT_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_permitTypehash_sorting() public view {
        bytes32 node1 = bytes32(uint256(0x2222));
        bytes32 node2 = bytes32(uint256(0x1111));

        bytes32 result = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);

        // Should sort: smaller first (node2, node1)
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(node2, node1));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, expectedNodesHash, keccak256("")));

        assertEq(result, expected, "Should sort nodes alphabetically with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test sorting behavior with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_nonceTypehash_sorting() public view {
        bytes32 node1 = bytes32(uint256(0x2222));
        bytes32 node2 = bytes32(uint256(0x1111));

        bytes32 result = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);

        // Should sort: smaller first (node2, node1)
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(node2, node1));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, expectedNodesHash, keccak256("")));

        assertEq(result, expected, "Should sort nodes alphabetically with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test order invariance with PERMIT_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_permitTypehash_orderInvariant() public view {
        bytes32 node1 = bytes32(uint256(0x1111));
        bytes32 node2 = bytes32(uint256(0x2222));

        bytes32 result1 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);
        bytes32 result2 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node2, node1);

        assertEq(result1, result2, "Should be order-invariant with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test order invariance with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndNode_nonceTypehash_orderInvariant() public view {
        bytes32 node1 = bytes32(uint256(0x1111));
        bytes32 node2 = bytes32(uint256(0x2222));

        bytes32 result1 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);
        bytes32 result2 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node2, node1);

        assertEq(result1, result2, "Should be order-invariant with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test with identical nodes
     */
    function test_combineNodeAndNode_identicalNodes() public view {
        bytes32 node = bytes32(uint256(0x1111));

        bytes32 permitResult = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node, node);
        bytes32 nonceResult = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node, node);

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test with zero hashes
     */
    function test_combineNodeAndNode_zeroHashes() public view {
        bytes32 zeroHash = bytes32(0);

        bytes32 permitResult = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, zeroHash, zeroHash);
        bytes32 nonceResult = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, zeroHash, zeroHash);

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
    }

    /**
     * Test different typehashes produce different outputs
     */
    function test_combineNodeAndNode_differentTypehashesProduceDifferentResults() public view {
        bytes32 node1 = keccak256("node1");
        bytes32 node2 = keccak256("node2");

        bytes32 permitResult = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);
        bytes32 nonceResult = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);

        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test deterministic results
     */
    function test_combineNodeAndNode_deterministic() public view {
        bytes32 node1 = bytes32(uint256(0x1111));
        bytes32 node2 = bytes32(uint256(0x2222));

        bytes32 permitResult1 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);
        bytes32 permitResult2 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node1, node2);

        bytes32 nonceResult1 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);
        bytes32 nonceResult2 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node1, node2);

        assertEq(permitResult1, permitResult2, "PERMIT should be deterministic");
        assertEq(nonceResult1, nonceResult2, "NONCE should be deterministic");
    }

    /**
     * Test all combination types produce different results
     */
    function test_combineNodeAndNode_differentFromLeafCombination() public view {
        bytes32 hash1 = bytes32(uint256(0x1111));
        bytes32 hash2 = bytes32(uint256(0x2222));

        bytes32 nodeNodeResult = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, hash1, hash2);
        bytes32 leafLeafResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, hash1, hash2);

        assertTrue(nodeNodeResult != leafLeafResult, "Node+Node should differ from Leaf+Leaf");
    }

    // ============================================
    // Category 4: combineNodeAndLeaf Tests (12 tests)
    // ============================================

    /**
     * Test basic mixed combination with PERMIT_NODE_TYPEHASH
     */
    function test_combineNodeAndLeaf_permitTypehash_basic() public view {
        bytes32 nodeHash = bytes32(uint256(0x1111));
        bytes32 leafHash = bytes32(uint256(0x2222));

        bytes32 result = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, nodeHash, leafHash);

        // Result should be Node(nodes=[nodeHash], leaves=[leafHash])
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(nodeHash));
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leafHash));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, expectedNodesHash, expectedLeavesHash));

        assertEq(result, expected, "Should create mixed Node with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test basic mixed combination with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndLeaf_nonceTypehash_basic() public view {
        bytes32 nodeHash = bytes32(uint256(0x1111));
        bytes32 leafHash = bytes32(uint256(0x2222));

        bytes32 result = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, nodeHash, leafHash);

        // Result should be Node(nodes=[nodeHash], leaves=[leafHash])
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(nodeHash));
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leafHash));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, expectedNodesHash, expectedLeavesHash));

        assertEq(result, expected, "Should create mixed Node with NONCE_NODE_TYPEHASH");
    }

    /**
     * CRITICAL TEST: NO SORTING - order matters
     */
    function test_combineNodeAndLeaf_permitTypehash_noSorting() public view {
        bytes32 nodeHash = bytes32(uint256(0x2222)); // Larger value
        bytes32 leafHash = bytes32(uint256(0x1111)); // Smaller value

        bytes32 result = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, nodeHash, leafHash);

        // Should maintain struct order: nodes first, leaves second (NO sorting)
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(nodeHash));
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leafHash));
        bytes32 expected = keccak256(abi.encode(PERMIT_NODE_TYPEHASH, expectedNodesHash, expectedLeavesHash));

        assertEq(result, expected, "Should maintain struct order (no sorting) with PERMIT_NODE_TYPEHASH");
    }

    /**
     * CRITICAL TEST: NO SORTING - order matters with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndLeaf_nonceTypehash_noSorting() public view {
        bytes32 nodeHash = bytes32(uint256(0x2222)); // Larger value
        bytes32 leafHash = bytes32(uint256(0x1111)); // Smaller value

        bytes32 result = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, nodeHash, leafHash);

        // Should maintain struct order: nodes first, leaves second (NO sorting)
        bytes32 expectedNodesHash = keccak256(abi.encodePacked(nodeHash));
        bytes32 expectedLeavesHash = keccak256(abi.encodePacked(leafHash));
        bytes32 expected = keccak256(abi.encode(NONCE_NODE_TYPEHASH, expectedNodesHash, expectedLeavesHash));

        assertEq(result, expected, "Should maintain struct order (no sorting) with NONCE_NODE_TYPEHASH");
    }

    /**
     * CRITICAL TEST: Order matters - combine(node, leaf) != combine(leaf, node)
     */
    function test_combineNodeAndLeaf_orderMatters_permit() public view {
        bytes32 hash1 = bytes32(uint256(0x1111));
        bytes32 hash2 = bytes32(uint256(0x2222));

        // First as node, second as leaf
        bytes32 result1 = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, hash1, hash2);
        // Swapped: first as node, second as leaf (but different values)
        bytes32 result2 = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, hash2, hash1);

        assertTrue(result1 != result2, "Order should matter for Node+Leaf combination with PERMIT");
    }

    /**
     * CRITICAL TEST: Order matters with NONCE_NODE_TYPEHASH
     */
    function test_combineNodeAndLeaf_orderMatters_nonce() public view {
        bytes32 hash1 = bytes32(uint256(0x1111));
        bytes32 hash2 = bytes32(uint256(0x2222));

        bytes32 result1 = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, hash1, hash2);
        bytes32 result2 = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, hash2, hash1);

        assertTrue(result1 != result2, "Order should matter for Node+Leaf combination with NONCE");
    }

    /**
     * Test with zero hashes
     */
    function test_combineNodeAndLeaf_zeroHashes() public view {
        bytes32 zeroHash = bytes32(0);

        bytes32 permitResult = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, zeroHash, zeroHash);
        bytes32 nonceResult = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, zeroHash, zeroHash);

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
    }

    /**
     * Test different typehashes produce different outputs
     */
    function test_combineNodeAndLeaf_differentTypehashesProduceDifferentResults() public view {
        bytes32 nodeHash = keccak256("node");
        bytes32 leafHash = keccak256("leaf");

        bytes32 permitResult = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, nodeHash, leafHash);
        bytes32 nonceResult = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, nodeHash, leafHash);

        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test deterministic results
     */
    function test_combineNodeAndLeaf_deterministic() public view {
        bytes32 nodeHash = bytes32(uint256(0x1111));
        bytes32 leafHash = bytes32(uint256(0x2222));

        bytes32 permitResult1 = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, nodeHash, leafHash);
        bytes32 permitResult2 = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, nodeHash, leafHash);

        bytes32 nonceResult1 = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, nodeHash, leafHash);
        bytes32 nonceResult2 = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, nodeHash, leafHash);

        assertEq(permitResult1, permitResult2, "PERMIT should be deterministic");
        assertEq(nonceResult1, nonceResult2, "NONCE should be deterministic");
    }

    /**
     * Test different from other combination types
     */
    function test_combineNodeAndLeaf_differentFromOtherCombinations() public view {
        bytes32 hash1 = bytes32(uint256(0x1111));
        bytes32 hash2 = bytes32(uint256(0x2222));

        bytes32 nodeLeafResult = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, hash1, hash2);
        bytes32 nodeNodeResult = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, hash1, hash2);
        bytes32 leafLeafResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, hash1, hash2);

        assertTrue(nodeLeafResult != nodeNodeResult, "Node+Leaf should differ from Node+Node");
        assertTrue(nodeLeafResult != leafLeafResult, "Node+Leaf should differ from Leaf+Leaf");
    }

    /**
     * Test with identical hashes
     */
    function test_combineNodeAndLeaf_identicalHashes() public view {
        bytes32 hash = bytes32(uint256(0x1111));

        bytes32 permitResult = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, hash, hash);
        bytes32 nonceResult = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, hash, hash);

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    // ============================================
    // Category 5: computeTreeHash Tests (24 tests)
    // ============================================

    /**
     * Test reconstruction with single leaf (no proof) - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_singleLeaf() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](0);
        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);

        // With empty proof, should return leaf unchanged
        assertEq(result, leaf, "Single leaf should return unchanged with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with single leaf (no proof) - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_singleLeaf() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](0);
        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        // With empty proof, should return leaf unchanged
        assertEq(result, leaf, "Single leaf should return unchanged with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with two leaves - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_twoLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        // Type flag = 0 (proof[0] is leaf)
        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);

        // Should combine as Leaf+Leaf
        bytes32 expected = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);

        assertEq(result, expected, "Two leaves should combine correctly with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with two leaves - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_twoLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        bytes32 expected = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);

        assertEq(result, expected, "Two leaves should combine correctly with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with three leaves - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_threeLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = leaf3;

        // All type flags = 0 (all leaves)
        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);

        // Step 1: combine leaf1 + leaf2 → node12
        bytes32 node12 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        // Step 2: combine node12 + leaf3 → final (Node+Leaf)
        bytes32 expected = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, node12, leaf3);

        assertEq(result, expected, "Three leaves should combine correctly with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with three leaves - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_threeLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = leaf3;

        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        bytes32 node12 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 expected = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, node12, leaf3);

        assertEq(result, expected, "Three leaves should combine correctly with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with four leaves (balanced) - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_fourLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");
        bytes32 leaf4 = keccak256("leaf4");

        // Pre-combine leaf3 + leaf4
        bytes32 node34 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf3, leaf4);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = node34;

        // Type flags: bit 8 = 0 (leaf2), bit 9 = 1 (node34)
        bytes32 proofStructure = bytes32(uint256(1) << (255 - 9));

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);

        // Step 1: leaf1 + leaf2 → node12
        bytes32 node12 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        // Step 2: node12 + node34 → final (Node+Node)
        bytes32 expected = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node12, node34);

        assertEq(result, expected, "Four leaves balanced tree with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with four leaves (balanced) - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_fourLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");
        bytes32 leaf4 = keccak256("leaf4");

        bytes32 node34 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf3, leaf4);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = node34;

        bytes32 proofStructure = bytes32(uint256(1) << (255 - 9));

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        bytes32 node12 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 expected = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node12, node34);

        assertEq(result, expected, "Four leaves balanced tree with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with five leaves (unbalanced) - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_fiveLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");
        bytes32 leaf4 = keccak256("leaf4");
        bytes32 leaf5 = keccak256("leaf5");

        // Pre-combine: node34 = leaf3 + leaf4
        bytes32 node34 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf3, leaf4);

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leaf2;
        proof[1] = node34;
        proof[2] = leaf5;

        // Type flags: bit 8 = 0 (leaf2), bit 9 = 1 (node34), bit 10 = 0 (leaf5)
        bytes32 proofStructure = bytes32(uint256(1) << (255 - 9));

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);

        // Step 1: leaf1 + leaf2 → node12
        bytes32 node12 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        // Step 2: node12 + node34 → node1234
        bytes32 node1234 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, node12, node34);
        // Step 3: node1234 + leaf5 → final
        bytes32 expected = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, node1234, leaf5);

        assertEq(result, expected, "Five leaves unbalanced tree with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction with five leaves (unbalanced) - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_fiveLeaves() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");
        bytes32 leaf4 = keccak256("leaf4");
        bytes32 leaf5 = keccak256("leaf5");

        bytes32 node34 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf3, leaf4);

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = leaf2;
        proof[1] = node34;
        proof[2] = leaf5;

        bytes32 proofStructure = bytes32(uint256(1) << (255 - 9));

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        bytes32 node12 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 node1234 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, node12, node34);
        bytes32 expected = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, node1234, leaf5);

        assertEq(result, expected, "Five leaves unbalanced tree with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test with mixed type flags - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_mixedTypes() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 node2 = keccak256("node2");
        bytes32 leaf3 = keccak256("leaf3");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = node2;
        proof[1] = leaf3;

        // Type flags: bit 8 = 1 (node2), bit 9 = 0 (leaf3)
        bytes32 proofStructure = bytes32(uint256(1) << (255 - 8));

        bytes32 result = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);

        // Step 1: leaf1 (current) + node2 (proof[0]) → Node+Leaf combination
        bytes32 step1 = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, node2, leaf1);
        // Step 2: step1 (now Node) + leaf3 (proof[1]) → Node+Leaf combination
        bytes32 expected = tester.combineNodeAndLeaf(PERMIT_NODE_TYPEHASH, step1, leaf3);

        assertEq(result, expected, "Mixed type flags with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test with mixed type flags - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_mixedTypes() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 node2 = keccak256("node2");
        bytes32 leaf3 = keccak256("leaf3");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = node2;
        proof[1] = leaf3;

        bytes32 proofStructure = bytes32(uint256(1) << (255 - 8));

        bytes32 result = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        bytes32 step1 = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, node2, leaf1);
        bytes32 expected = tester.combineNodeAndLeaf(NONCE_NODE_TYPEHASH, step1, leaf3);

        assertEq(result, expected, "Mixed type flags with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test different typehashes produce different roots for same tree structure
     */
    function test_reconstructTreeHash_differentTypehashesProduceDifferentRoots() public view {
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        bytes32 proofStructure = bytes32(0);

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf1);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf1);

        assertTrue(permitResult != nonceResult, "Different typehashes should produce different roots");
    }

    /**
     * Test reconstruction is deterministic - PERMIT
     */
    function test_reconstructTreeHash_permitTypehash_deterministic() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("proof0");
        proof[1] = keccak256("proof1");

        bytes32 proofStructure = bytes32(0);

        bytes32 result1 = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 result2 = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertEq(result1, result2, "Reconstruction should be deterministic with PERMIT_NODE_TYPEHASH");
    }

    /**
     * Test reconstruction is deterministic - NONCE
     */
    function test_reconstructTreeHash_nonceTypehash_deterministic() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("proof0");
        proof[1] = keccak256("proof1");

        bytes32 proofStructure = bytes32(0);

        bytes32 result1 = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 result2 = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertEq(result1, result2, "Reconstruction should be deterministic with NONCE_NODE_TYPEHASH");
    }

    /**
     * Test with all type flags set to 0 (all leaves)
     */
    function test_reconstructTreeHash_allLeaves() public view {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = keccak256("leaf2");
        proof[1] = keccak256("leaf3");
        proof[2] = keccak256("leaf4");

        bytes32 proofStructure = bytes32(0); // All leaves

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, keccak256("leaf1"));
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, keccak256("leaf1"));

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test with alternating type flags
     */
    function test_reconstructTreeHash_alternatingTypes() public view {
        bytes32[] memory proof = new bytes32[](4);
        proof[0] = keccak256("proof0"); // Node (bit 8 = 1)
        proof[1] = keccak256("proof1"); // Leaf (bit 9 = 0)
        proof[2] = keccak256("proof2"); // Node (bit 10 = 1)
        proof[3] = keccak256("proof3"); // Leaf (bit 11 = 0)

        // Type flags: alternating pattern
        bytes32 proofStructure = bytes32(
            (uint256(1) << (255 - 8)) // bit 8 = 1
                | (uint256(1) << (255 - 10)) // bit 10 = 1
        );

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, keccak256("leaf"));
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, keccak256("leaf"));

        assertTrue(permitResult != bytes32(0), "PERMIT result should be non-zero");
        assertTrue(nonceResult != bytes32(0), "NONCE result should be non-zero");
    }

    /**
     * Test position byte doesn't affect reconstruction
     */
    function test_reconstructTreeHash_positionByteIgnored() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("proof");

        // Different positions, same type flags
        bytes32 proofStructure1 = bytes32(uint256(0) << 248);
        bytes32 proofStructure2 = bytes32(uint256(42) << 248);

        bytes32 permitResult1 = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure1, proof, leaf);
        bytes32 permitResult2 = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure2, proof, leaf);

        assertEq(permitResult1, permitResult2, "Position byte should not affect reconstruction");
    }

    /**
     * Test with long proof
     */
    function test_reconstructTreeHash_longProof() public view {
        bytes32 leaf = keccak256("leaf");

        // Create proof with 10 elements
        bytes32[] memory proof = new bytes32[](10);
        for (uint256 i = 0; i < 10; i++) {
            proof[i] = keccak256(abi.encodePacked("proof", i));
        }

        bytes32 proofStructure = bytes32(0); // All leaves

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertTrue(permitResult != bytes32(0), "PERMIT should handle long proof");
        assertTrue(nonceResult != bytes32(0), "NONCE should handle long proof");
        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Test with maximum allowed proof length (247)
     */
    function test_reconstructTreeHash_maxProofLength() public view {
        bytes32 leaf = keccak256("leaf");

        // Create proof with 247 elements (maximum allowed)
        bytes32[] memory proof = new bytes32[](247);
        for (uint256 i = 0; i < 247; i++) {
            proof[i] = keccak256(abi.encodePacked("proof", i));
        }

        bytes32 proofStructure = bytes32(0); // All leaves

        // Should not revert
        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertTrue(permitResult != bytes32(0), "PERMIT should handle max proof length");
        assertTrue(nonceResult != bytes32(0), "NONCE should handle max proof length");
    }

    /**
     * Test empty proof returns leaf unchanged
     */
    function test_reconstructTreeHash_emptyProofReturnsLeaf() public view {
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](0);
        bytes32 proofStructure = bytes32(0);

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertEq(permitResult, leaf, "Empty proof should return leaf unchanged with PERMIT");
        assertEq(nonceResult, leaf, "Empty proof should return leaf unchanged with NONCE");
    }

    // ============================================
    // Category 6: Edge Cases (5 tests)
    // ============================================

    /**
     * Test proof length exceeds maximum (should revert)
     */
    function test_proofLengthExceedsMaximum() public {
        bytes32 leaf = keccak256("leaf");

        // Create proof with 248 elements (exceeds maximum of 247)
        bytes32[] memory proof = new bytes32[](248);
        for (uint256 i = 0; i < 248; i++) {
            proof[i] = keccak256(abi.encodePacked("proof", i));
        }

        bytes32 proofStructure = bytes32(0);

        // Should revert with "Proof exceeds maximum depth"
        vm.expectRevert("Proof exceeds maximum depth");
        tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);

        vm.expectRevert("Proof exceeds maximum depth");
        tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);
    }

    /**
     * Test unused type flags must be zero
     */
    function test_unusedTypeFlagsMustBeZero() public {
        bytes32 leaf = keccak256("leaf");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("proof0");
        proof[1] = keccak256("proof1");

        // Set unused type flags (beyond bit 8+2 = bit 10)
        // Valid bits are 8 and 9 (for proof[0] and proof[1])
        // Set bit 0 (invalid - way past used range)
        bytes32 proofStructure = bytes32(uint256(1)); // Bit 0 set (invalid)

        vm.expectRevert("Unused type flags must be zero");
        tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);

        vm.expectRevert("Unused type flags must be zero");
        tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);
    }

    /**
     * Test with all max values
     */
    function test_edgeCase_allMaxValues() public view {
        bytes32 maxHash = bytes32(type(uint256).max);

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = maxHash;
        proof[1] = maxHash;
        proof[2] = maxHash;

        // For proof.length = 3, only 3 type flag bits should be set (bits 247, 246, 245)
        // Set all 3 valid type flags to 1
        bytes32 proofStructure = bytes32(uint256(0x7) << (256 - 8 - 3)); // 0x7 = 0b111 (3 bits set)

        // Should handle max values without reverting
        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, maxHash);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, maxHash);

        assertTrue(permitResult != bytes32(0), "Should handle max values with PERMIT");
        assertTrue(nonceResult != bytes32(0), "Should handle max values with NONCE");
    }

    /**
     * Test with all zero values
     */
    function test_edgeCase_allZeroValues() public view {
        bytes32 zeroHash = bytes32(0);

        bytes32[] memory proof = new bytes32[](3);
        proof[0] = zeroHash;
        proof[1] = zeroHash;
        proof[2] = zeroHash;

        bytes32 proofStructure = bytes32(0);

        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, zeroHash);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, zeroHash);

        assertTrue(permitResult != bytes32(0), "Should handle zero values with PERMIT");
        assertTrue(nonceResult != bytes32(0), "Should handle zero values with NONCE");
    }

    /**
     * Test valid proofStructure with position and flags
     */
    function test_edgeCase_validProofStructureWithPosition() public view {
        bytes32 leaf = keccak256("leaf");

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("proof0");
        proof[1] = keccak256("proof1");

        // Position = 42, type flags for 2 elements
        uint8 position = 42;
        uint256 validFlags = 0x3 << (256 - 8 - 2); // Set bits 247 and 246
        bytes32 proofStructure = bytes32(validFlags | (uint256(position) << 248));

        // Should not revert
        bytes32 permitResult = tester.computeTreeHash(PERMIT_NODE_TYPEHASH, proofStructure, proof, leaf);
        bytes32 nonceResult = tester.computeTreeHash(NONCE_NODE_TYPEHASH, proofStructure, proof, leaf);

        assertTrue(permitResult != bytes32(0), "Should handle position with valid flags (PERMIT)");
        assertTrue(nonceResult != bytes32(0), "Should handle position with valid flags (NONCE)");
    }

    // ============================================
    // Category 7: Fuzz Tests (10 tests)
    // ============================================

    /**
     * Fuzz test: combineLeafAndLeaf is commutative
     */
    function testFuzz_combineLeafAndLeaf_commutative(
        bytes32 leaf1,
        bytes32 leaf2,
        bytes32 typehash
    ) public view {
        bytes32 result1 = tester.combineLeafAndLeaf(typehash, leaf1, leaf2);
        bytes32 result2 = tester.combineLeafAndLeaf(typehash, leaf2, leaf1);

        assertEq(result1, result2, "Leaf combination should be commutative");
    }

    /**
     * Fuzz test: combineNodeAndNode is commutative
     */
    function testFuzz_combineNodeAndNode_commutative(
        bytes32 node1,
        bytes32 node2,
        bytes32 typehash
    ) public view {
        bytes32 result1 = tester.combineNodeAndNode(typehash, node1, node2);
        bytes32 result2 = tester.combineNodeAndNode(typehash, node2, node1);

        assertEq(result1, result2, "Node combination should be commutative");
    }

    /**
     * Fuzz test: combineNodeAndLeaf is NOT commutative
     */
    function testFuzz_combineNodeAndLeaf_notCommutative(
        bytes32 hash1,
        bytes32 hash2,
        bytes32 typehash
    ) public view {
        vm.assume(hash1 != hash2); // Skip identical hashes

        bytes32 result1 = tester.combineNodeAndLeaf(typehash, hash1, hash2);
        bytes32 result2 = tester.combineNodeAndLeaf(typehash, hash2, hash1);

        assertTrue(result1 != result2, "Node+Leaf should NOT be commutative");
    }

    /**
     * Fuzz test: Reconstruction with empty proof returns leaf
     */
    function testFuzz_reconstructTreeHash_emptyProof(
        bytes32 typehash,
        bytes32 leaf
    ) public view {
        bytes32[] memory proof = new bytes32[](0);
        bytes32 proofStructure = bytes32(0);

        bytes32 result = tester.computeTreeHash(typehash, proofStructure, proof, leaf);

        assertEq(result, leaf, "Empty proof should return leaf unchanged");
    }

    /**
     * Fuzz test: Reconstruction is deterministic
     */
    function testFuzz_reconstructTreeHash_deterministic(
        bytes32 typehash,
        bytes32 leaf,
        bytes32[5] memory proofElements,
        uint8 proofLength
    ) public view {
        proofLength = uint8(bound(proofLength, 0, 5));

        bytes32[] memory proof = new bytes32[](proofLength);
        for (uint256 i = 0; i < proofLength; i++) {
            proof[i] = proofElements[i];
        }

        // Valid type flags (all zeros for simplicity)
        bytes32 proofStructure = bytes32(0);

        bytes32 result1 = tester.computeTreeHash(typehash, proofStructure, proof, leaf);
        bytes32 result2 = tester.computeTreeHash(typehash, proofStructure, proof, leaf);

        assertEq(result1, result2, "Reconstruction should be deterministic");
    }

    /**
     * Fuzz test: Different typehashes produce different results
     */
    function testFuzz_differentTypehashesProduceDifferentResults(
        bytes32 leaf1,
        bytes32 leaf2
    ) public view {
        vm.assume(leaf1 != leaf2); // Need different leaves to make it interesting

        bytes32 permitResult = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, leaf1, leaf2);
        bytes32 nonceResult = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, leaf1, leaf2);

        assertTrue(permitResult != nonceResult, "Different typehashes should produce different results");
    }

    /**
     * Fuzz test: All combinations produce non-zero results
     */
    function testFuzz_combinationsProduceNonZero(
        bytes32 hash1,
        bytes32 hash2,
        bytes32 typehash
    ) public view {
        bytes32 leafLeaf = tester.combineLeafAndLeaf(typehash, hash1, hash2);
        bytes32 nodeNode = tester.combineNodeAndNode(typehash, hash1, hash2);
        bytes32 nodeLeaf = tester.combineNodeAndLeaf(typehash, hash1, hash2);

        assertTrue(leafLeaf != bytes32(0), "Leaf+Leaf should produce non-zero");
        assertTrue(nodeNode != bytes32(0), "Node+Node should produce non-zero");
        assertTrue(nodeLeaf != bytes32(0), "Node+Leaf should produce non-zero");
    }

    /**
     * Fuzz test: Reconstruction with constrained proof length
     */
    function testFuzz_reconstructTreeHash_constrainedProofLength(
        bytes32 typehash,
        bytes32 leaf,
        uint8 proofLength
    ) public view {
        vm.assume(proofLength <= 247); // Max proof length

        bytes32[] memory proof = new bytes32[](proofLength);
        for (uint256 i = 0; i < proofLength; i++) {
            proof[i] = keccak256(abi.encodePacked(typehash, i));
        }

        bytes32 proofStructure = bytes32(0); // All leaves

        // Should not revert
        bytes32 result = tester.computeTreeHash(typehash, proofStructure, proof, leaf);
        assertTrue(result != bytes32(0) || proofLength == 0, "Should handle valid proof lengths");
    }

    /**
     * Fuzz test: Position byte doesn't affect result
     */
    function testFuzz_positionByteDoesNotAffectResult(
        bytes32 typehash,
        bytes32 leaf,
        bytes32 proofElement,
        uint8 position1,
        uint8 position2
    ) public view {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proofElement;

        // Same type flags, different positions
        bytes32 proofStructure1 = bytes32(uint256(position1) << 248);
        bytes32 proofStructure2 = bytes32(uint256(position2) << 248);

        bytes32 result1 = tester.computeTreeHash(typehash, proofStructure1, proof, leaf);
        bytes32 result2 = tester.computeTreeHash(typehash, proofStructure2, proof, leaf);

        assertEq(result1, result2, "Position byte should not affect result");
    }

    /**
     * Fuzz test: Sorting consistency across typehashes
     */
    function testFuzz_sortingConsistentAcrossTypehashes(
        bytes32 hash1,
        bytes32 hash2
    ) public view {
        // Test Leaf+Leaf sorting
        bytes32 permitLeaf1 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, hash1, hash2);
        bytes32 permitLeaf2 = tester.combineLeafAndLeaf(PERMIT_NODE_TYPEHASH, hash2, hash1);
        assertEq(permitLeaf1, permitLeaf2, "PERMIT Leaf+Leaf should be commutative");

        bytes32 nonceLeaf1 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, hash1, hash2);
        bytes32 nonceLeaf2 = tester.combineLeafAndLeaf(NONCE_NODE_TYPEHASH, hash2, hash1);
        assertEq(nonceLeaf1, nonceLeaf2, "NONCE Leaf+Leaf should be commutative");

        // Test Node+Node sorting
        bytes32 permitNode1 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, hash1, hash2);
        bytes32 permitNode2 = tester.combineNodeAndNode(PERMIT_NODE_TYPEHASH, hash2, hash1);
        assertEq(permitNode1, permitNode2, "PERMIT Node+Node should be commutative");

        bytes32 nonceNode1 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, hash1, hash2);
        bytes32 nonceNode2 = tester.combineNodeAndNode(NONCE_NODE_TYPEHASH, hash2, hash1);
        assertEq(nonceNode1, nonceNode2, "NONCE Node+Node should be commutative");
    }
}
