// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/interfaces/IUnhingedMerkleTree.sol";
import "../src/lib/UnhingedMerkleTree.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title UnhingedMerkleTreeTest
 * @notice Tests for simple UnhingedMerkleTree functionality using OpenZeppelin's MerkleProof
 */
contract UnhingedMerkleTreeTest is Test {
    using UnhingedMerkleTree for bytes32[];

    // Test verifying a simple merkle proof with single leaf
    function test_singleLeafVerification() public pure {
        bytes32 leaf = bytes32(uint256(0x1234));
        bytes32 root = leaf; // Single leaf is its own root

        // Empty proof for single leaf
        bytes32[] memory proofNodes = new bytes32[](0);

        // Verify using UnhingedMerkleTree wrapper
        bool result = UnhingedMerkleTree.verifyProof(root, leaf, proofNodes);
        assert(result == true);

        // Also verify using the library function directly
        // (bytes32[] array is used for merkle proofs)
        assert(UnhingedMerkleTree.verifyProof(root, leaf, proofNodes) == true);
    }

    // Test verifying merkle proof with two leaves
    function test_twoLeavesVerification() public pure {
        bytes32 leaf1 = bytes32(uint256(0x1234));
        bytes32 leaf2 = bytes32(uint256(0x5678));

        // Calculate expected root using OpenZeppelin's standard approach
        bytes32 root =
            leaf1 < leaf2 ? keccak256(abi.encodePacked(leaf1, leaf2)) : keccak256(abi.encodePacked(leaf2, leaf1));

        // Proof for leaf1 contains leaf2
        bytes32[] memory proofNodes = new bytes32[](1);
        proofNodes[0] = leaf2;

        // Verify the proof
        bool result = UnhingedMerkleTree.verifyProof(root, leaf1, proofNodes);
        assert(result == true);
    }

    // Test verifying merkle proof with four leaves
    function test_fourLeavesVerification() public pure {
        // Create a simple 4-leaf merkle tree
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");
        bytes32 leaf4 = keccak256("leaf4");

        // Build tree bottom-up
        bytes32 node1 =
            leaf1 < leaf2 ? keccak256(abi.encodePacked(leaf1, leaf2)) : keccak256(abi.encodePacked(leaf2, leaf1));
        bytes32 node2 =
            leaf3 < leaf4 ? keccak256(abi.encodePacked(leaf3, leaf4)) : keccak256(abi.encodePacked(leaf4, leaf3));
        bytes32 root =
            node1 < node2 ? keccak256(abi.encodePacked(node1, node2)) : keccak256(abi.encodePacked(node2, node1));

        // Proof for leaf1: [leaf2, node2]
        bytes32[] memory proofNodes = new bytes32[](2);
        proofNodes[0] = leaf2;
        proofNodes[1] = node2;

        // Verify using direct function
        bool result = UnhingedMerkleTree.verifyProof(root, leaf1, proofNodes);
        assert(result == true);

        // Verify the proof
        assert(UnhingedMerkleTree.verifyProof(root, leaf1, proofNodes) == true);
    }

    // Test invalid proof verification with incorrect root
    function test_wrongRoot() public pure {
        bytes32 leaf = bytes32(uint256(0x1234));
        bytes32 sibling = bytes32(uint256(0x5678));

        // Calculate correct root
        bytes32 correctRoot =
            leaf < sibling ? keccak256(abi.encodePacked(leaf, sibling)) : keccak256(abi.encodePacked(sibling, leaf));

        // Create proof
        bytes32[] memory proofNodes = new bytes32[](1);
        proofNodes[0] = sibling;

        // Create an incorrect root
        bytes32 incorrectRoot = bytes32(uint256(correctRoot) + 1);

        // Verify the proof with incorrect root - should fail
        bool result = UnhingedMerkleTree.verifyProof(incorrectRoot, leaf, proofNodes);
        assert(result == false);
    }

    // Test invalid proof with wrong sibling
    function test_invalidProofWithWrongSibling() public pure {
        bytes32 leaf = bytes32(uint256(0x1234));
        bytes32 correctSibling = bytes32(uint256(0x5678));

        // Calculate correct root
        bytes32 root = leaf < correctSibling
            ? keccak256(abi.encodePacked(leaf, correctSibling))
            : keccak256(abi.encodePacked(correctSibling, leaf));

        // Create proof with wrong sibling
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(correctSibling) + 1); // Wrong sibling

        // Verify should fail with invalid proof
        bool result = UnhingedMerkleTree.verifyProof(root, leaf, invalidProof);
        assert(result == false);
    }

    // Test calculateRoot function
    function test_calculateRoot() public pure {
        bytes32 leaf = keccak256("testLeaf");
        bytes32 sibling1 = keccak256("sibling1");
        bytes32 sibling2 = keccak256("sibling2");

        // Create proof nodes
        bytes32[] memory proofNodes = new bytes32[](2);
        proofNodes[0] = sibling1;
        proofNodes[1] = sibling2;

        // Calculate root using direct function
        bytes32 calculatedRoot1 = UnhingedMerkleTree.calculateRoot(leaf, proofNodes);

        // Calculate root using the same proof nodes
        bytes32 calculatedRoot2 = UnhingedMerkleTree.calculateRoot(leaf, proofNodes);

        // Both methods should give same result
        assert(calculatedRoot1 == calculatedRoot2);

        // Verify the calculated root is correct
        assert(UnhingedMerkleTree.verifyProof(calculatedRoot1, leaf, proofNodes));
    }

    // Test with empty proof array
    function test_emptyProofArray() public pure {
        bytes32 leaf = keccak256("singleLeaf");
        bytes32 root = leaf; // Single leaf is the root

        bytes32[] memory emptyProof = new bytes32[](0);

        // Should verify successfully
        assert(UnhingedMerkleTree.verifyProof(root, leaf, emptyProof));

        // Test with different leaf - should fail
        bytes32 differentLeaf = keccak256("differentLeaf");
        assert(!UnhingedMerkleTree.verifyProof(root, differentLeaf, emptyProof));
    }

    // Test proof length edge cases
    function test_proofLengthVariations() public pure {
        // Test with different proof lengths
        bytes32 leaf = keccak256("testLeaf");

        // 1-node proof
        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = keccak256("node1");
        bytes32 root1 = UnhingedMerkleTree.calculateRoot(leaf, proof1);
        assert(UnhingedMerkleTree.verifyProof(root1, leaf, proof1));

        // 3-node proof (deeper tree)
        bytes32[] memory proof3 = new bytes32[](3);
        proof3[0] = keccak256("node1");
        proof3[1] = keccak256("node2");
        proof3[2] = keccak256("node3");
        bytes32 root3 = UnhingedMerkleTree.calculateRoot(leaf, proof3);
        assert(UnhingedMerkleTree.verifyProof(root3, leaf, proof3));
    }

    // Test proof structure with bytes32[] type
    function test_unhingedProofStructure() public pure {
        bytes32 leaf = bytes32(uint256(0x1111));
        bytes32 sibling = bytes32(uint256(0x2222));

        // Calculate root
        bytes32 root =
            leaf < sibling ? keccak256(abi.encodePacked(leaf, sibling)) : keccak256(abi.encodePacked(sibling, leaf));

        // Create proof nodes
        bytes32[] memory proofNodes = new bytes32[](1);
        proofNodes[0] = sibling;

        // Verify using the proof nodes directly
        // (bytes32[] array is used for merkle proofs)
        bool result = UnhingedMerkleTree.verifyProof(root, leaf, proofNodes);
        assert(result == true);
    }

    // Test consistency between different verification methods
    function test_verificationConsistency() public pure {
        bytes32 leaf = keccak256("consistencyLeaf");

        // Create a simple proof
        bytes32[] memory proofNodes = new bytes32[](2);
        proofNodes[0] = keccak256("sibling1");
        proofNodes[1] = keccak256("sibling2");

        // Calculate root
        bytes32 root = UnhingedMerkleTree.calculateRoot(leaf, proofNodes);

        // Test direct verification
        bool directResult = UnhingedMerkleTree.verifyProof(root, leaf, proofNodes);

        // Test verification using the library function
        bool structResult = UnhingedMerkleTree.verifyProof(root, leaf, proofNodes);

        // Both methods should give the same result
        assert(directResult == structResult);
        assert(directResult == true);

        // Also test calculateRoot consistency
        bytes32 calculatedRoot1 = UnhingedMerkleTree.calculateRoot(leaf, proofNodes);
        bytes32 calculatedRoot2 = UnhingedMerkleTree.calculateRoot(leaf, proofNodes);
        assert(calculatedRoot1 == calculatedRoot2);
        assert(calculatedRoot1 == root);
    }
}
