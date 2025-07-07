// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/interfaces/IUnhingedMerkleTree.sol";
import "../../src/lib/UnhingedMerkleTree.sol";

/**
 * @title UnhingedMerkleTreeTester
 * @notice Helper contract to expose UnhingedMerkleTree library functions for testing
 */
contract UnhingedMerkleTreeTester {
    using UnhingedMerkleTree for bytes32;
    using UnhingedMerkleTree for bytes32[];
    using UnhingedMerkleTree for IUnhingedMerkleTree.UnhingedProof;

    /**
     * @notice Creates an unhinged root from chain hashes
     */
    function createUnhingedRoot(
        bytes32[] calldata hashes
    ) external pure returns (bytes32) {
        return UnhingedMerkleTree.createUnhingedRoot(hashes);
    }

    /**
     * @notice Creates an optimized proof structure
     * @param preHash Previous hashes combined (can be zero for hasPreHash=false)
     * @param subtreeProof The balanced merkle proof
     * @param followingHashes Array of following hash nodes
     * @return Optimized UnhingedProof structure
     */
    function createOptimizedProof(
        bytes32 preHash,
        bytes32[] memory subtreeProof,
        bytes32[] memory followingHashes
    ) external pure returns (IUnhingedMerkleTree.UnhingedProof memory) {
        return UnhingedMerkleTree.createOptimizedProof(preHash, subtreeProof, followingHashes);
    }

    /**
     * @notice Exposes packCounts function for testing
     * @param subtreeProofCount Number of nodes in subtree proof (max 2^120-1)
     * @param followingHashesCount Number of following hashes (max 2^120-1)
     * @param hasPreHash Flag indicating if preHash is present
     * @return Packed counts as bytes32
     */
    function packCounts(
        uint120 subtreeProofCount,
        uint120 followingHashesCount,
        bool hasPreHash
    ) external pure returns (bytes32) {
        return UnhingedMerkleTree.packCounts(subtreeProofCount, followingHashesCount, hasPreHash);
    }

    /**
     * @notice Exposes extractCounts function for testing
     * @param counts Packed counts value
     * @return subtreeProofCount Number of nodes in subtree proof
     * @return followingHashesCount Number of following hashes
     * @return hasPreHash Flag indicating if preHash is present
     */
    function extractCounts(
        bytes32 counts
    ) external pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) {
        return UnhingedMerkleTree.extractCounts(counts);
    }

    /**
     * @notice Exposes hashLink function for testing
     * @param a First hash
     * @param b Second hash
     * @return Combined hash
     */
    function hashLink(bytes32 a, bytes32 b) external pure returns (bytes32) {
        return UnhingedMerkleTree.hashLink(a, b);
    }

    /**
     * @notice Exposes verify function for testing
     * @param leaf The leaf node being proven
     * @param proof The unhinged proof structure
     * @param expectedRoot The expected unhinged root
     * @return True if valid, false otherwise
     */
    function verify(
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof calldata proof,
        bytes32 expectedRoot
    ) external pure returns (bool) {
        return proof.verify(expectedRoot, leaf);
    }

    /**
     * @notice Exposes computeBalancedRoot function for testing
     * @param leaf The leaf node to verify
     * @param proof The balanced Merkle proof for the leaf
     * @return The calculated subtree root
     */
    function verifyBalancedSubtree(bytes32 leaf, bytes32[] calldata proof) external pure returns (bytes32) {
        return UnhingedMerkleTree.computeBalancedRoot(leaf, uint120(proof.length), proof);
    }

    /**
     * @notice Force packing with potential overflows for testing
     * @dev This is for testing error conditions with overflow values
     * @param subtreeProofCount Number of nodes in subtree proof (will overflow if too large)
     * @param followingHashesCount Number of following hashes (will overflow if too large)
     * @param hasPreHash Flag indicating if preHash is present
     * @return Packed counts as bytes32
     */
    function forcePack(
        uint256 subtreeProofCount,
        uint256 followingHashesCount,
        bool hasPreHash
    ) external pure returns (bytes32) {
        // This will invoke the library function which does overflow checking
        return UnhingedMerkleTree.packCounts(
            uint120(subtreeProofCount), // Will trigger overflow if too large
            uint120(followingHashesCount), // Will trigger overflow if too large
            hasPreHash
        );
    }
}
