// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUnhingedMerkleTree } from "../interfaces/IUnhingedMerkleTree.sol";

/**
 * @title UnhingedMerkleTree
 * @notice A library implementing Unhinged Merkle Tree structure for cross-chain proofs
 * @dev Optimized data structure for efficient and secure cross-chain verification
 */
library UnhingedMerkleTree {
    /// @dev Bit shift amount for extracting subtreeProofCount from packed counts
    /// @dev First 120 bits store the subtree proof count
    uint256 private constant SUBTREE_PROOF_COUNT_SHIFT = 136;

    /// @dev Bit shift amount for extracting followingHashesCount from packed counts
    /// @dev Next 120 bits (after subtreeProofCount) store the following hashes count
    uint256 private constant FOLLOWING_HASHES_COUNT_SHIFT = 16;

    /// @dev Bitmask for extracting 120-bit values
    /// @dev (1 << 120) - 1 creates a mask with 120 ones
    uint256 private constant UINT120_MASK = (1 << 120) - 1;

    /// @dev Bitmask for extracting the hasPreHash flag from the last bit
    uint256 private constant HAS_PRE_HASH_MASK = 1;

    /// @dev Starting index for subtree proof nodes when preHash is not present
    uint256 private constant SUBTREE_PROOF_START_INDEX = 0;

    /// @dev Starting index for following hashes when preHash is present
    uint256 private constant FOLLOWING_HASHES_START_WITH_PREHASH = 1;

    /**
     * @dev Verifies an Unhinged Merkle proof
     * @param leaf The leaf node being proven
     * @param proof The optimized proof structure containing all necessary components
     * @param unhingedRoot The signed root of the complete unhinged tree
     * @return True if the proof is valid, false otherwise
     */
    function verify(
        IUnhingedMerkleTree.UnhingedProof calldata proof,
        bytes32 unhingedRoot,
        bytes32 leaf
    ) internal pure returns (bool) {
        // Validate the proof structure and calculate the root
        bytes32 calculatedRoot = calculateRoot(proof, leaf);

        // Verify the calculated root matches the signed root
        return calculatedRoot == unhingedRoot;
    }

    /**
     * @dev Extract counts from packed bytes32
     * @param counts The packed counts value
     * @return subtreeProofCount Number of nodes in the subtree proof
     * @return followingHashesCount Number of nodes in the following hashes
     * @return hasPreHash Flag indicating if preHash is present
     */
    function extractCounts(
        bytes32 counts
    ) internal pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) {
        uint256 value = uint256(counts);

        // Extract the different parts from the packed value
        subtreeProofCount = uint120(value >> SUBTREE_PROOF_COUNT_SHIFT); // First 120 bits
        followingHashesCount = uint120((value >> FOLLOWING_HASHES_COUNT_SHIFT) & UINT120_MASK); // Next 120 bits
        // Skip 15 bits reserved for future use
        hasPreHash = (value & HAS_PRE_HASH_MASK) == HAS_PRE_HASH_MASK; // Last bit
    }

    /**
     * @dev Pack counts into a single bytes32
     * @param subtreeProofCount Number of nodes in the subtree proof
     * @param followingHashesCount Number of nodes in the following hashes
     * @param hasPreHash Flag indicating if preHash is present
     * @return counts The packed counts value
     */
    function packCounts(
        uint120 subtreeProofCount,
        uint120 followingHashesCount,
        bool hasPreHash
    ) internal pure returns (bytes32 counts) {
        // Pack the values
        uint256 packedValue = 0;
        packedValue |= uint256(subtreeProofCount) << SUBTREE_PROOF_COUNT_SHIFT; // First 120 bits
        packedValue |= uint256(followingHashesCount) << FOLLOWING_HASHES_COUNT_SHIFT; // Next 120 bits
        // Bits 1-15 are reserved for future use (zeros)
        if (hasPreHash) {
            packedValue |= HAS_PRE_HASH_MASK; // Set the last bit if preHash is present
        }

        counts = bytes32(packedValue);
    }

    /**
     * @dev Computes the root of a balanced Merkle tree from a leaf and proof
     * @param proofNodes The array containing proof nodes
     * @param proofLength The number of proof elements to use from the array
     * @param leaf The leaf node being proven
     * @return The calculated root of the balanced subtree
     */
    function computeBalancedRoot(
        bytes32 leaf,
        uint120 proofLength,
        bytes32[] calldata proofNodes
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proofLength; i++) {
            bytes32 proofElement = proofNodes[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash;
    }

    /**
     * @dev Creates an unhinged root from a list of balanced subtree roots
     * @param subtreeRoots Array of balanced subtree roots in canonical order
     * @return The unhinged root hash
     */
    function createUnhingedRoot(
        bytes32[] memory subtreeRoots
    ) internal pure returns (bytes32) {
        uint256 subtreeRootsLength = subtreeRoots.length;
        if (subtreeRootsLength == 0) {
            return bytes32(0);
        }

        bytes32 unhingedRoot = subtreeRoots[0];

        for (uint256 i = 1; i < subtreeRootsLength; i++) {
            unhingedRoot = hashLink(unhingedRoot, subtreeRoots[i]);
        }

        return unhingedRoot;
    }

    /**
     * @dev Computes a single hash in the unhinged chain
     * @param previousHash The hash of previous operations
     * @param currentHash The hash to append
     * @return The combined hash
     */
    function hashLink(bytes32 previousHash, bytes32 currentHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(previousHash, currentHash));
    }

    /**
     * @dev Validates a proof structure and returns validation components for internal use
     * @param proof The unhinged proof structure to validate
     * @return isValid True if the proof structure is valid, false otherwise
     * @return subtreeProofCount Number of nodes in the subtree proof portion
     * @return followingHashesCount Number of nodes in the following hashes portion
     * @return hasPreHash Flag indicating if preHash optimization is used
     * @return expectedNodeCount Expected exact number of nodes based on the packed counts
     * @notice This function performs comprehensive validation:
     *         1. Extracts counts from the packed proof.counts field
     *         2. Calculates expected node count: subtreeProof + followingHashes + (preHash ? 1 : 0)
     *         3. Validates that proof.nodes.length matches expectedNodeCount exactly
     *         4. Checks for inconsistent hasPreHash flag (true but first node is zero)
     * @notice Returns validation results without reverting to enable custom error handling
     */
    function _validateProofStructure(
        IUnhingedMerkleTree.UnhingedProof calldata proof
    )
        private
        pure
        returns (
            bool isValid,
            uint120 subtreeProofCount,
            uint120 followingHashesCount,
            bool hasPreHash,
            uint256 expectedNodeCount
        )
    {
        // Extract counts from packed data
        (subtreeProofCount, followingHashesCount, hasPreHash) = extractCounts(proof.counts);

        // Calculate expected exact node count
        expectedNodeCount = subtreeProofCount + followingHashesCount;
        if (hasPreHash) {
            expectedNodeCount += 1;
        }

        // Check for exact node count match
        if (proof.nodes.length != expectedNodeCount) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, expectedNodeCount);
        }

        // Check for inconsistent hasPreHash flag
        if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, expectedNodeCount);
        }

        // All validation passed
        return (true, subtreeProofCount, followingHashesCount, hasPreHash, expectedNodeCount);
    }

    /**
     * @dev Verifies an Unhinged Merkle Tree proof structure without reverting
     * @param proof The unhinged proof structure
     * @return True if the proof structure is valid, false otherwise
     * @notice Performs validation checks on the proof structure and returns a boolean instead of reverting.
     *         This makes it suitable for conditional verification. The actual root calculation
     *         happens in calculateRoot after validation.
     */
    function verifyProofStructure(
        IUnhingedMerkleTree.UnhingedProof calldata proof
    ) internal pure returns (bool) {
        (bool isValid,,,,) = _validateProofStructure(proof);
        return isValid;
    }

    /**
     * @dev Calculates the unhinged root from a leaf and proof with validation checks
     * @param leaf The leaf node to calculate from
     * @param proof The unhinged proof structure
     * @return The calculated unhinged root
     * @notice This function performs validation checks on the proof structure
     *         before calculating the root. It supports the hasPreHash optimization.
     */
    function calculateRoot(
        IUnhingedMerkleTree.UnhingedProof calldata proof,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        // Validate the proof structure with our helper function
        (
            bool isValid,
            uint120 subtreeProofCount,
            uint120 followingHashesCount,
            bool hasPreHash,
            uint256 expectedNodeCount
        ) = _validateProofStructure(proof);

        // If validation fails, revert with appropriate reason
        if (!isValid) {
            if (proof.nodes.length != expectedNodeCount) {
                revert IUnhingedMerkleTree.InvalidNodeArrayLength(expectedNodeCount, proof.nodes.length);
            }

            if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
                revert IUnhingedMerkleTree.InconsistentPreHashFlag(true, bytes32(0));
            }

            // Catch-all for any other validation issues
            revert IUnhingedMerkleTree.InvalidParameters();
        }

        return _computeRoot(proof, leaf, subtreeProofCount, followingHashesCount, hasPreHash);
    }

    /**
     * @dev Computes the unhinged root from pre-validated proof components
     * @param proof The unhinged proof structure (must be pre-validated)
     * @param leaf The leaf node being proven in the merkle tree
     * @param subtreeProofCount Number of nodes in the subtree proof portion
     * @param followingHashesCount Number of nodes in the following hashes chain
     * @param hasPreHash Flag indicating if preHash optimization is used
     * @return The calculated unhinged root hash
     * @notice This function assumes the proof structure has been validated and computes:
     *         1. If hasPreHash: starts with hashLink(preHash, leaf) then adds following hashes
     *         2. If !hasPreHash: computes balanced subtree root, then adds following hashes
     * @notice The unhinged structure allows efficient cross-chain proofs by:
     *         - Using preHash to represent all previous chain computations
     *         - Or using subtreeProof for the current chain's balanced tree
     *         - Then chaining followingHashes for subsequent chains
     */
    function _computeRoot(
        IUnhingedMerkleTree.UnhingedProof calldata proof,
        bytes32 leaf,
        uint120 subtreeProofCount,
        uint120 followingHashesCount,
        bool hasPreHash
    ) private pure returns (bytes32) {
        bytes32 calculatedRoot;

        if (hasPreHash) {
            // Structure: [preHash, followingHashes...]
            // Use preHash directly as the starting point
            calculatedRoot = hashLink(proof.nodes[0], leaf);
        } else {
            // Structure: [subtreeProof..., followingHashes...]
            // Compute subtree root using existing array
            calculatedRoot = computeBalancedRoot(leaf, subtreeProofCount, proof.nodes);
        }

        // Add all following chain hashes
        uint256 start = hasPreHash ? FOLLOWING_HASHES_START_WITH_PREHASH : subtreeProofCount;
        uint256 end = start + followingHashesCount;
        for (uint256 i = start; i < end; i++) {
            calculatedRoot = hashLink(calculatedRoot, proof.nodes[i]);
        }

        return calculatedRoot;
    }

    /**
     * @dev Conversion function to create optimized proof from component parts
     * @param preHash Previous hashes combined (can be zero to indicate no preHash)
     * @param subtreeProof The balanced merkle proof
     * @param followingHashes The array of following hashes
     * @return optimizedProof The compact proof structure
     */
    function createOptimizedProof(
        bytes32 preHash,
        bytes32[] memory subtreeProof,
        bytes32[] memory followingHashes
    ) internal pure returns (IUnhingedMerkleTree.UnhingedProof memory optimizedProof) {
        // Check if preHash is present (non-zero)
        bool hasPreHash = preHash != bytes32(0);

        // Validate that preHash and subtreeProof are mutually exclusive
        if (hasPreHash && subtreeProof.length > 0) {
            revert IUnhingedMerkleTree.InvalidParameters();
        }

        // Determine array size needed
        uint256 nodesArraySize = subtreeProof.length + followingHashes.length + (hasPreHash ? 1 : 0);

        // Create the combined nodes array
        bytes32[] memory nodes = new bytes32[](nodesArraySize);

        uint256 currentIndex = 0;

        if (hasPreHash) {
            // Structure: [preHash, followingHashes...]
            nodes[currentIndex++] = preHash;
        } else {
            // Structure: [subtreeProof..., followingHashes...]
            uint256 subtreeProofLength = subtreeProof.length;
            for (uint256 i = 0; i < subtreeProofLength; i++) {
                nodes[currentIndex++] = subtreeProof[i];
            }
        }

        // Add following hash nodes
        uint256 followingHashesLength = followingHashes.length;
        for (uint256 i = 0; i < followingHashesLength; i++) {
            nodes[currentIndex++] = followingHashes[i];
        }

        // 4. Pack the counts with the hasPreHash flag
        bytes32 counts = packCounts(uint120(subtreeProof.length), uint120(followingHashes.length), hasPreHash);

        // 5. Create and return the optimized proof
        optimizedProof = IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });
    }
}
