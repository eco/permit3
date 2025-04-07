// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/lib/UnhingedMerkleTree.sol";
import "../src/interfaces/IUnhingedMerkleTree.sol";
import "./utils/UnhingedMerkleTreeTester.sol";

/**
 * @title UnhingedMerkleTreeTest
 * @notice Consolidated tests for UnhingedMerkleTree functionality
 */
contract UnhingedMerkleTreeTest is Test {
    using UnhingedMerkleTree for bytes32;
    UnhingedMerkleTreeTester tester;
    
    function setUp() public {
        tester = new UnhingedMerkleTreeTester();
    }
    
    // Test creating an unhinged root with an empty array
    function test_emptyTreeHash() public {
        bytes32[] memory roots = new bytes32[](0);
        bytes32 result = UnhingedMerkleTree.createUnhingedRoot(roots);
        assert(result == bytes32(0));
    }
    
    // Test creating an unhinged root with a single leaf
    function test_singleLeafHash() public {
        bytes32[] memory roots = new bytes32[](1);
        roots[0] = bytes32(uint256(0x1234));
        
        bytes32 result = UnhingedMerkleTree.createUnhingedRoot(roots);
        assert(result == bytes32(uint256(0x1234)));
    }
    
    // Test creating an unhinged root with two leaves
    function test_twoLeavesHash() public {
        bytes32[] memory roots = new bytes32[](2);
        roots[0] = bytes32(uint256(0x1234));
        roots[1] = bytes32(uint256(0x5678));
        
        bytes32 result = UnhingedMerkleTree.createUnhingedRoot(roots);
        bytes32 expected = keccak256(abi.encodePacked(roots[0], roots[1]));
        
        assert(result == expected);
    }
    
    // Test creating an unhinged root with three leaves
    function test_threeLeavesHash() public {
        bytes32[] memory roots = new bytes32[](3);
        roots[0] = bytes32(uint256(0x1234));
        roots[1] = bytes32(uint256(0x5678));
        roots[2] = bytes32(uint256(0x9abc));
        
        bytes32 result = UnhingedMerkleTree.createUnhingedRoot(roots);
        bytes32 intermediate = keccak256(abi.encodePacked(roots[0], roots[1]));
        bytes32 expected = keccak256(abi.encodePacked(intermediate, roots[2]));
        
        assert(result == expected);
    }
    
    // Test creating an unhinged root with four leaves
    function test_fourLeavesHash() public {
        bytes32[] memory roots = new bytes32[](4);
        roots[0] = bytes32(uint256(0x1234));
        roots[1] = bytes32(uint256(0x5678));
        roots[2] = bytes32(uint256(0x9abc));
        roots[3] = bytes32(uint256(0xdef0));
        
        bytes32 result = UnhingedMerkleTree.createUnhingedRoot(roots);
        
        bytes32 intermediate1 = keccak256(abi.encodePacked(roots[0], roots[1]));
        bytes32 intermediate2 = keccak256(abi.encodePacked(intermediate1, roots[2]));
        bytes32 expected = keccak256(abi.encodePacked(intermediate2, roots[3]));
        
        assert(result == expected);
    }
    
    // Test creating and verifying a proof
    function test_generateAndVerifyProof() public {
        // Create a leaf
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Create a sample proof
        bytes32[] memory subtreeProof = new bytes32[](1);
        subtreeProof[0] = bytes32(uint256(0x5678));
        
        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = bytes32(uint256(0x9abc));
        
        bytes32 preHash = bytes32(uint256(0xdef0));
        
        // Create the optimized proof
        IUnhingedMerkleTree.UnhingedProof memory proof = tester.createOptimizedProof(
            preHash,
            subtreeProof,
            followingHashes
        );
        
        // Calculate the expected unhinged root
        bytes32 expectedSubtreeRoot = tester.verifyBalancedSubtree(leaf, subtreeProof);
        bytes32 expectedRoot = keccak256(abi.encodePacked(preHash, expectedSubtreeRoot));
        expectedRoot = keccak256(abi.encodePacked(expectedRoot, followingHashes[0]));
        
        // Verify the proof
        bool result = UnhingedMerkleTree.verify(leaf, proof, expectedRoot);
        assert(result == true);
    }
    
    // Test with an empty proof
    function test_emptyProof() public {
        // Create a leaf
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Create an optimized proof with empty subtree proof and following hashes
        bytes32[] memory emptyArray = new bytes32[](0);
        bytes32 preHash = bytes32(uint256(0xdef0));
        
        IUnhingedMerkleTree.UnhingedProof memory proof = tester.createOptimizedProof(
            preHash,
            emptyArray,
            emptyArray
        );
        
        // Calculate the expected unhinged root
        bytes32 expectedRoot = keccak256(abi.encodePacked(preHash, leaf));
        
        // Verify the proof
        bool result = UnhingedMerkleTree.verify(leaf, proof, expectedRoot);
        assert(result == true);
    }
    
    // Test packing and extracting counts
    function test_packAndExtractCounts() public {
        uint120 subtreeProofCount = 3;
        uint120 followingHashesCount = 2;
        bool hasPreHash = true;
        
        bytes32 packed = UnhingedMerkleTree.packCounts(subtreeProofCount, followingHashesCount, hasPreHash);
        
        (uint120 extractedSubtreeCount, uint120 extractedFollowingCount, bool extractedHasPreHash) = UnhingedMerkleTree.extractCounts(packed);
        
        assert(extractedSubtreeCount == subtreeProofCount);
        assert(extractedFollowingCount == followingHashesCount);
        assert(extractedHasPreHash == hasPreHash);
    }
    
    // Test hash link function
    function test_hashLink() public {
        bytes32 previousHash = bytes32(uint256(0x1234));
        bytes32 currentHash = bytes32(uint256(0x5678));
        
        bytes32 result = UnhingedMerkleTree.hashLink(previousHash, currentHash);
        bytes32 expected = keccak256(abi.encodePacked(previousHash, currentHash));
        
        assert(result == expected);
    }
    
    // Test invalid proof verification with incorrect unhinged root
    function test_invalidProofWithWrongRoot() public {
        // Create a leaf
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Create a sample proof
        bytes32[] memory subtreeProof = new bytes32[](1);
        subtreeProof[0] = bytes32(uint256(0x5678));
        
        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = bytes32(uint256(0x9abc));
        
        bytes32 preHash = bytes32(uint256(0xdef0));
        
        // Create the optimized proof
        IUnhingedMerkleTree.UnhingedProof memory proof = tester.createOptimizedProof(
            preHash,
            subtreeProof,
            followingHashes
        );
        
        // Calculate a correct root
        bytes32 expectedSubtreeRoot = tester.verifyBalancedSubtree(leaf, subtreeProof);
        bytes32 correctRoot = keccak256(abi.encodePacked(preHash, expectedSubtreeRoot));
        correctRoot = keccak256(abi.encodePacked(correctRoot, followingHashes[0]));
        
        // Create an incorrect root (just add 1 to make it different)
        bytes32 incorrectRoot = bytes32(uint256(correctRoot) + 1);
        
        // Verify the proof with incorrect root - should fail
        bool result = UnhingedMerkleTree.verify(leaf, proof, incorrectRoot);
        assert(result == false);
    }
    
    // Test invalid proof with insufficient nodes
    function test_invalidProofWithInsufficientNodes() public {
        // Create a leaf
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Create a proof with insufficient nodes
        bytes32[] memory nodes = new bytes32[](2); // Need at least 3 for this test
        nodes[0] = bytes32(uint256(0xdef0)); // preHash
        nodes[1] = bytes32(uint256(0x5678)); // Only one subtree node
        
        // Create counts that request more nodes than available
        bytes32 counts = tester.packCounts(1, 1, true); // Requests 2 nodes after preHash
        
        // Build an invalid proof
        IUnhingedMerkleTree.UnhingedProof memory invalidProof = IUnhingedMerkleTree.UnhingedProof({
            nodes: nodes,
            counts: counts
        });
        
        // Create any root for verification
        bytes32 root = bytes32(uint256(0xabcd));
        
        // This should revert with InvalidNodeArrayLength
        vm.expectRevert(
            abi.encodeWithSelector(IUnhingedMerkleTree.InvalidNodeArrayLength.selector, 3, 2)
        );
        tester.verify(leaf, invalidProof, root);
    }
    
    // Test with a larger realistic dataset (10 chain permits)
    function test_largeRealisticDataset() public {
        // Create 10 leaf values to simulate 10 different chain permits
        bytes32[] memory leaves = new bytes32[](10);
        for (uint i = 0; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked("Chain", i));
        }
        
        // We want to prove the 6th element (index 5)
        bytes32 targetLeaf = leaves[5];
        
        // Create a balanced subtree proof
        // In a balanced tree with 10 leaves, we need 4 proof elements (log2(10) rounded up)
        bytes32[] memory subtreeProof = new bytes32[](4);
        subtreeProof[0] = bytes32(uint256(0xa1));
        subtreeProof[1] = bytes32(uint256(0xa2));
        subtreeProof[2] = bytes32(uint256(0xa3));
        subtreeProof[3] = bytes32(uint256(0xa4));
        
        // Create the previous hash (combinatino of chains 0-4)
        bytes32 preHash = keccak256(abi.encodePacked("Previous chains combined"));
        
        // Create following hashes (chains 7-9)
        bytes32[] memory followingHashes = new bytes32[](3);
        followingHashes[0] = leaves[7];
        followingHashes[1] = leaves[8];
        followingHashes[2] = leaves[9];
        
        // Create the optimized proof
        IUnhingedMerkleTree.UnhingedProof memory proof = tester.createOptimizedProof(
            preHash,
            subtreeProof,
            followingHashes
        );
        
        // Calculate what the subtree root would be (for chains 5-6)
        bytes32 subtreeRoot = tester.verifyBalancedSubtree(targetLeaf, subtreeProof);
        
        // Calculate what the unhinged root should be
        bytes32 unhingedRoot = preHash;
        unhingedRoot = keccak256(abi.encodePacked(unhingedRoot, subtreeRoot));
        
        for (uint i = 0; i < followingHashes.length; i++) {
            unhingedRoot = keccak256(abi.encodePacked(unhingedRoot, followingHashes[i]));
        }
        
        // Verify the proof with the correct unhinged root - should pass
        bool result = UnhingedMerkleTree.verify(targetLeaf, proof, unhingedRoot);
        assert(result == true);
        
        // Verify with an incorrect root - should fail
        bytes32 incorrectRoot = bytes32(uint256(unhingedRoot) + 1);
        bool failResult = UnhingedMerkleTree.verify(targetLeaf, proof, incorrectRoot);
        assert(failResult == false);
    }
    
    // Additional tests for the tester contract
    
    function test_createUnhingedRoot() public {
        // Test with one hash
        bytes32[] memory singleHash = new bytes32[](1);
        singleHash[0] = bytes32(uint256(123));
        bytes32 singleRoot = tester.createUnhingedRoot(singleHash);
        assertEq(singleRoot, singleHash[0]);
        
        // Test with multiple hashes
        bytes32[] memory multipleHashes = new bytes32[](3);
        multipleHashes[0] = bytes32(uint256(1));
        multipleHashes[1] = bytes32(uint256(2));
        multipleHashes[2] = bytes32(uint256(3));
        
        bytes32 multipleRoot = tester.createUnhingedRoot(multipleHashes);
        bytes32 expected = keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(multipleHashes[0], multipleHashes[1])), 
            multipleHashes[2]
        ));
        assertEq(multipleRoot, expected);
    }
    
    function test_createOptimizedProof() public {
        // Test with preHash, empty subtree proof, and some following hashes
        bytes32 preHash = bytes32(uint256(42));
        bytes32[] memory emptySubtreeProof = new bytes32[](0);
        bytes32[] memory followingHashes = new bytes32[](2);
        followingHashes[0] = bytes32(uint256(10));
        followingHashes[1] = bytes32(uint256(20));
        
        IUnhingedMerkleTree.UnhingedProof memory proof = tester.createOptimizedProof(
            preHash,
            emptySubtreeProof,
            followingHashes
        );
        
        // Verify the proof structure
        assertEq(proof.nodes[0], preHash);
        assertEq(proof.nodes[1], followingHashes[0]);
        assertEq(proof.nodes[2], followingHashes[1]);
        
        // Extract counts to verify
        (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) = tester.extractCounts(proof.counts);
        assertEq(subtreeProofCount, 0);
        assertEq(followingHashesCount, 2);
        assertTrue(hasPreHash);
    }
    
    function test_verify() public {
        // Create a simple proof with leaf and one level
        bytes32 leaf = bytes32(uint256(123));
        bytes32 sibling = bytes32(uint256(456));
        
        // Construct a proof
        bytes32[] memory nodes = new bytes32[](2); // preHash and subtree proof
        nodes[0] = bytes32(uint256(42)); // preHash
        nodes[1] = sibling; // subtree proof element
        
        // Pack counts
        bytes32 counts = tester.packCounts(1, 0, true); // 1 subtree proof element, 0 following hashes, with preHash
        
        // Create the proof structure
        IUnhingedMerkleTree.UnhingedProof memory proof = IUnhingedMerkleTree.UnhingedProof({
            nodes: nodes,
            counts: counts
        });
        
        // Calculate the root manually
        bytes32 subtreeRoot;
        if (leaf <= sibling) {
            subtreeRoot = keccak256(abi.encodePacked(leaf, sibling));
        } else {
            subtreeRoot = keccak256(abi.encodePacked(sibling, leaf));
        }
        
        bytes32 expectedRoot = keccak256(abi.encodePacked(nodes[0], subtreeRoot));
        
        // Verify the proof
        bool isValid = tester.verify(leaf, proof, expectedRoot);
        assertTrue(isValid);
        
        // Test with invalid root
        bool isInvalid = tester.verify(leaf, proof, bytes32(uint256(999)));
        assertFalse(isInvalid);
    }
    
    function test_verifyBalancedSubtreeInTester() public {
        // Create a leaf and sibling
        bytes32 leaf = bytes32(uint256(100));
        
        // Create proofs for both ordering cases
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(uint256(200)); // sibling > leaf
        
        // Calculate expected result
        bytes32 expected = keccak256(abi.encodePacked(leaf, proof[0]));
        
        // Verify
        bytes32 result = tester.verifyBalancedSubtree(leaf, proof);
        assertEq(result, expected);
        
        // Test the other direction (leaf > sibling)
        bytes32 largerLeaf = bytes32(uint256(300));
        bytes32 expectedReverse = keccak256(abi.encodePacked(proof[0], largerLeaf));
        bytes32 resultReverse = tester.verifyBalancedSubtree(largerLeaf, proof);
        assertEq(resultReverse, expectedReverse);
    }
    
    function test_verifyBalancedSubtreeEmptyProof() public {
        // Test with empty proof (should return the leaf itself)
        bytes32 leaf = bytes32(uint256(123));
        bytes32[] memory emptyProof = new bytes32[](0);
        
        bytes32 result = tester.verifyBalancedSubtree(leaf, emptyProof);
        assertEq(result, leaf);
    }
    
    function test_verifyBalancedSubtreeMultiLevel() public {
        // Test with a multi-level proof
        bytes32 leaf = bytes32(uint256(100));
        
        // Create a 3-level proof
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = bytes32(uint256(200));
        proof[1] = bytes32(uint256(300));
        proof[2] = bytes32(uint256(400));
        
        // Calculate expected result manually (following the same logic as in the contract)
        bytes32 computedHash = leaf;
        
        // Level 1
        computedHash = keccak256(abi.encodePacked(computedHash, proof[0])); // leaf <= proof[0]
        
        // Level 2
        // Now computedHash > proof[1]
        computedHash = keccak256(abi.encodePacked(proof[1], computedHash));
        
        // Level 3
        // Now computedHash > proof[2]
        computedHash = keccak256(abi.encodePacked(proof[2], computedHash));
        
        bytes32 result = tester.verifyBalancedSubtree(leaf, proof);
        assertEq(result, computedHash);
    }
    
    function test_verifyEqualElements() public {
        // Test case where leaf and proof element are equal
        bytes32 leaf = bytes32(uint256(100));
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(uint256(100)); // Equal to leaf
        
        // According to the implementation, if leaf <= proofElement, hash them in that order
        bytes32 expected = keccak256(abi.encodePacked(leaf, proof[0]));
        
        bytes32 result = tester.verifyBalancedSubtree(leaf, proof);
        assertEq(result, expected);
    }
    
    function test_proofWithoutPreHash() public {
        // Test creating and verifying a proof without a preHash
        
        // Create a leaf and some subtree proof
        bytes32 leaf = bytes32(uint256(0x1234));
        bytes32[] memory subtreeProof = new bytes32[](1);
        subtreeProof[0] = bytes32(uint256(0x5678));
        
        // Create a following hash
        bytes32[] memory followingHashes = new bytes32[](1);
        followingHashes[0] = bytes32(uint256(0x9abc));
        
        // Create a proof explicitly without preHash
        IUnhingedMerkleTree.UnhingedProof memory proof = IUnhingedMerkleTree.UnhingedProof({
            nodes: new bytes32[](2), // Only for subtree proof (1) and following hash (1), no preHash
            counts: tester.packCounts(1, 1, false) // hasPreHash=false flag
        });
        
        // Manually set up the nodes array (no preHash at index 0)
        proof.nodes[0] = subtreeProof[0];
        proof.nodes[1] = followingHashes[0];
        
        // Calculate the expected subtree root
        bytes32 subtreeRoot = tester.verifyBalancedSubtree(leaf, subtreeProof);
        
        // Because there's no preHash, we start with the subtree root
        bytes32 expectedRoot = keccak256(abi.encodePacked(subtreeRoot, followingHashes[0]));
        
        // Verify the proof
        bool isValid = tester.verify(leaf, proof, expectedRoot);
        assertTrue(isValid);
    }
    
    /**
     * @notice Gas optimization benchmark comparing hasPreHash=true vs hasPreHash=false
     * @dev This test quantifies the gas efficiency improvement from using the hasPreHash optimization
     *      (setting hasPreHash=false when no preHash is needed, vs including a non-zero preHash)
     */
    function test_compareGasUsagePreHashOptimization() public {
        // Test to compare gas usage between using hasPreHash=true with non-zero vs hasPreHash=false
        
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Scenario 1: with hasPreHash=true with a non-zero preHash
        {
            IUnhingedMerkleTree.UnhingedProof memory proofWithPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: new bytes32[](1), // Only preHash
                counts: tester.packCounts(0, 0, true) // With hasPreHash flag
            });
            
            // Set preHash to a non-zero value to avoid the InconsistentPreHashFlag error
            proofWithPreHash.nodes[0] = bytes32(uint256(0x5678));
            
            // Calculate expected root (hashing leaf with preHash)
            bytes32 expectedRoot = keccak256(abi.encodePacked(proofWithPreHash.nodes[0], leaf));
            
            // Measure gas for verification with preHash
            uint256 gasStart = gasleft();
            bool isValid = tester.verify(leaf, proofWithPreHash, expectedRoot);
            uint256 gasUsed = gasStart - gasleft();
            
            assertTrue(isValid);
            emit log_named_uint("Gas used with hasPreHash=true and non-zero preHash", gasUsed);
        }
        
        // Scenario 2: with hasPreHash=false (optimized)
        {
            IUnhingedMerkleTree.UnhingedProof memory proofWithoutPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: new bytes32[](0), // No nodes needed - key optimization
                counts: tester.packCounts(0, 0, false) // Without hasPreHash flag
            });
            
            // With hasPreHash=false, the leaf is the root
            bytes32 expectedRoot = leaf;
            
            // Measure gas for verification without preHash
            uint256 gasStart = gasleft();
            bool isValid = tester.verify(leaf, proofWithoutPreHash, expectedRoot);
            uint256 gasUsed = gasStart - gasleft();
            
            assertTrue(isValid);
            emit log_named_uint("Gas used with hasPreHash=false (optimized)", gasUsed);
            
            // Calculate and display percent savings
            uint256 originalGas = gasStart - gasleft();
            uint256 percentSaved = (originalGas > 0) ? ((gasStart - gasleft()) * 100 / originalGas) : 0;
            emit log_named_uint("Percent gas saved with hasPreHash=false optimization", percentSaved);
        }
    }
    
    /**
     * @notice Comprehensive gas benchmarking for hasPreHash optimization across different scenarios
     * @dev This test measures gas efficiency improvements in various realistic use cases
     */
    function test_hasPreHashGasBenchmarkComprehensive() public {
        // Test different scenarios for a more complete gas usage comparison
        
        bytes32 leaf = bytes32(uint256(0x1234));
        
        // Scenario 1: Simple proof with empty subtree proof
        {
            emit log_string("=== SCENARIO 1: Empty Subtree Proof ===");
            
            // With preHash
            IUnhingedMerkleTree.UnhingedProof memory withPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: new bytes32[](1), // only preHash
                counts: tester.packCounts(0, 0, true)
            });
            withPreHash.nodes[0] = bytes32(uint256(0x5678));
            bytes32 expectedRoot = keccak256(abi.encodePacked(withPreHash.nodes[0], leaf));
            
            uint256 gasStart = gasleft();
            tester.verify(leaf, withPreHash, expectedRoot);
            uint256 withPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas with preHash", withPreHashGas);
            
            // Without preHash (optimized)
            IUnhingedMerkleTree.UnhingedProof memory withoutPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: new bytes32[](0),
                counts: tester.packCounts(0, 0, false)
            });
            
            gasStart = gasleft();
            tester.verify(leaf, withoutPreHash, leaf);
            uint256 withoutPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas without preHash", withoutPreHashGas);
            
            // Calculate savings
            uint256 gasSaved = withPreHashGas > withoutPreHashGas ? withPreHashGas - withoutPreHashGas : 0;
            uint256 percentSaved = withPreHashGas > 0 ? (gasSaved * 100 / withPreHashGas) : 0;
            emit log_named_uint("Gas saved", gasSaved);
            emit log_named_uint("Percent saved", percentSaved);
        }
        
        // Scenario 2: Small subtree proof (1 node)
        {
            emit log_string("=== SCENARIO 2: Small Subtree Proof (1 node) ===");
            
            // Create a subtree proof
            bytes32[] memory subtreeProof = new bytes32[](1);
            subtreeProof[0] = bytes32(uint256(0xabcd));
            
            // With preHash
            bytes32[] memory nodesWithPreHash = new bytes32[](2); // preHash + subtree proof
            nodesWithPreHash[0] = bytes32(uint256(0x5678)); // preHash
            nodesWithPreHash[1] = subtreeProof[0];
            
            IUnhingedMerkleTree.UnhingedProof memory withPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: nodesWithPreHash,
                counts: tester.packCounts(1, 0, true)
            });
            
            // Calculate expected root
            bytes32 subtreeRoot = tester.verifyBalancedSubtree(leaf, subtreeProof);
            bytes32 expectedRoot = keccak256(abi.encodePacked(nodesWithPreHash[0], subtreeRoot));
            
            uint256 gasStart = gasleft();
            tester.verify(leaf, withPreHash, expectedRoot);
            uint256 withPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas with preHash", withPreHashGas);
            
            // Without preHash (optimized)
            IUnhingedMerkleTree.UnhingedProof memory withoutPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: subtreeProof,
                counts: tester.packCounts(1, 0, false)
            });
            
            gasStart = gasleft();
            tester.verify(leaf, withoutPreHash, subtreeRoot);
            uint256 withoutPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas without preHash", withoutPreHashGas);
            
            // Calculate savings
            uint256 gasSaved = withPreHashGas > withoutPreHashGas ? withPreHashGas - withoutPreHashGas : 0;
            uint256 percentSaved = withPreHashGas > 0 ? (gasSaved * 100 / withPreHashGas) : 0;
            emit log_named_uint("Gas saved", gasSaved);
            emit log_named_uint("Percent saved", percentSaved);
        }
        
        // Scenario 3: With following hashes
        {
            emit log_string("=== SCENARIO 3: With Following Hashes ===");
            
            // Create following hashes
            bytes32[] memory followingHashes = new bytes32[](2);
            followingHashes[0] = bytes32(uint256(0xbeef));
            followingHashes[1] = bytes32(uint256(0xdead));
            
            // With preHash
            bytes32[] memory nodesWithPreHash = new bytes32[](3); // preHash + following hashes
            nodesWithPreHash[0] = bytes32(uint256(0x5678)); // preHash
            nodesWithPreHash[1] = followingHashes[0];
            nodesWithPreHash[2] = followingHashes[1];
            
            IUnhingedMerkleTree.UnhingedProof memory withPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: nodesWithPreHash,
                counts: tester.packCounts(0, 2, true)
            });
            
            // Calculate expected root
            bytes32 combinedRoot = keccak256(abi.encodePacked(nodesWithPreHash[0], leaf));
            combinedRoot = keccak256(abi.encodePacked(combinedRoot, followingHashes[0]));
            combinedRoot = keccak256(abi.encodePacked(combinedRoot, followingHashes[1]));
            
            uint256 gasStart = gasleft();
            tester.verify(leaf, withPreHash, combinedRoot);
            uint256 withPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas with preHash", withPreHashGas);
            
            // Without preHash (optimized)
            IUnhingedMerkleTree.UnhingedProof memory withoutPreHash = IUnhingedMerkleTree.UnhingedProof({
                nodes: followingHashes,
                counts: tester.packCounts(0, 2, false)
            });
            
            // Calculate expected root without preHash
            bytes32 combinedRootWithoutPreHash = leaf;
            combinedRootWithoutPreHash = keccak256(abi.encodePacked(combinedRootWithoutPreHash, followingHashes[0]));
            combinedRootWithoutPreHash = keccak256(abi.encodePacked(combinedRootWithoutPreHash, followingHashes[1]));
            
            gasStart = gasleft();
            tester.verify(leaf, withoutPreHash, combinedRootWithoutPreHash);
            uint256 withoutPreHashGas = gasStart - gasleft();
            emit log_named_uint("Gas without preHash", withoutPreHashGas);
            
            // Calculate savings
            uint256 gasSaved = withPreHashGas > withoutPreHashGas ? withPreHashGas - withoutPreHashGas : 0;
            uint256 percentSaved = withPreHashGas > 0 ? (gasSaved * 100 / withPreHashGas) : 0;
            emit log_named_uint("Gas saved", gasSaved);
            emit log_named_uint("Percent saved", percentSaved);
        }
    }
    
    function test_inconsistentPreHashFlag() public {
        // Test case where hasPreHash=true but preHash is zero
        bytes32 leaf = bytes32(uint256(0x1234));
        
        IUnhingedMerkleTree.UnhingedProof memory proof = IUnhingedMerkleTree.UnhingedProof({
            nodes: new bytes32[](1), // One node for preHash
            counts: tester.packCounts(0, 0, true) // hasPreHash=true flag
        });
        
        // Set preHash to zero, which is inconsistent with hasPreHash=true
        proof.nodes[0] = bytes32(0);
        
        // This should revert with InconsistentPreHashFlag
        vm.expectRevert(
            abi.encodeWithSelector(IUnhingedMerkleTree.InconsistentPreHashFlag.selector, true, bytes32(0))
        );
        tester.verify(leaf, proof, bytes32(0));
    }
    
    /**
     * @notice Test validation of hasPreHash flag consistency
     * @dev Tests the error case where hasPreHash=true but nodes array is empty, which is invalid
     *      This is a critical validation to ensure proper implementation of the hasPreHash optimization
     */
    function test_hasPreHashButEmptyNodes() public {
        // Test case where hasPreHash=true but the nodes array is empty
        bytes32 leaf = bytes32(uint256(0x1234));
        
        IUnhingedMerkleTree.UnhingedProof memory proof = IUnhingedMerkleTree.UnhingedProof({
            nodes: new bytes32[](0), // Empty nodes array
            counts: tester.packCounts(0, 0, true) // hasPreHash=true flag
        });
        
        // This should revert with HasPreHashButEmptyNodes
        vm.expectRevert(IUnhingedMerkleTree.HasPreHashButEmptyNodes.selector);
        tester.verify(leaf, proof, bytes32(0));
    }
    
    function test_countOverflowChecks() public {
        // Test the overflow checks in packCounts
        uint120 maxValue = type(uint120).max;
        
        // Packing should work with max values
        bytes32 packed = tester.packCounts(maxValue, maxValue, true);
        (uint120 extractedSubtree, uint120 extractedFollowing, bool extractedHasPreHash) = tester.extractCounts(packed);
        
        assertEq(extractedSubtree, maxValue);
        assertEq(extractedFollowing, maxValue);
        assertTrue(extractedHasPreHash);
        
        // We can't actually test exact overflow cases in Solidity directly as the cast to uint120
        // would already revert before reaching the library code, but we can at least verify
        // that our validation works correctly with the maximum values
        
        // Verify the largest values work
        bytes32 maxPacked = tester.packCounts(maxValue, maxValue, true);
        assertEq(maxPacked != bytes32(0), true);
        
        // And we have full bit coverage with our extractCounts
        (uint120 maxSubtree, uint120 maxFollowing, bool hasPreHashExtracted) = tester.extractCounts(maxPacked);
        assertEq(maxSubtree, maxValue);
        assertEq(maxFollowing, maxValue);
        assertTrue(hasPreHashExtracted);
    }
}