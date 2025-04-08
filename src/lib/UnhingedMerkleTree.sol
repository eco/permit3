// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUnhingedMerkleTree } from "../interfaces/IUnhingedMerkleTree.sol";

/**
 * @title UnhingedMerkleTree
 * @notice A library implementing Unhinged Merkle Tree structure for cross-chain proofs
 * @dev Optimized data structure for efficient and secure cross-chain verification
 */
library UnhingedMerkleTree {
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
        subtreeProofCount = uint120(value >> 136); // First 120 bits
        followingHashesCount = uint120((value >> 16) & ((1 << 120) - 1)); // Next 120 bits
        // Skip 15 bits reserved for future use
        hasPreHash = (value & 1) == 1; // Last bit
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
        // Make sure the values fit within the bit ranges
        require(subtreeProofCount < (1 << 120), "SubtreeProofCount overflow");
        require(followingHashesCount < (1 << 120), "FollowingHashesCount overflow");

        // Pack the values
        uint256 packedValue = 0;
        packedValue |= uint256(subtreeProofCount) << 136; // First 120 bits
        packedValue |= uint256(followingHashesCount) << 16; // Next 120 bits
        // Bits 1-15 are reserved for future use (zeros)
        if (hasPreHash) {
            packedValue |= 1; // Set the last bit if preHash is present
        }

        counts = bytes32(packedValue);
    }

    /**
     * @dev Verifies a standard Merkle proof for a balanced subtree
     * @param proof The Merkle proof (sibling hashes)
     * @param leaf The leaf node being proven
     * @return The calculated root of the balanced subtree
     */
    function verifyBalancedSubtree(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        return verifyBalancedSubtreeWithOffset(proof, 0, uint120(proof.length), leaf);
    }

    /**
     * @dev Verifies a standard Merkle proof for a balanced subtree using offset and count
     * @param proofNodes The array containing all proof nodes
     * @param startIndex The starting index in the proofNodes array
     * @param proofLength The number of proof elements to use from the array
     * @param leaf The leaf node being proven
     * @return The calculated root of the balanced subtree
     */
    function verifyBalancedSubtreeWithOffset(
        bytes32[] calldata proofNodes,
        uint256 startIndex,
        uint120 proofLength,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proofLength; i++) {
            bytes32 proofElement = proofNodes[startIndex + i];

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
        if (subtreeRoots.length == 0) {
            return bytes32(0);
        }

        bytes32 unhingedRoot = subtreeRoots[0];

        for (uint256 i = 1; i < subtreeRoots.length; i++) {
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
     * @dev Validates a proof structure and returns validation components
     * @param proof The unhinged proof structure to validate
     * @return isValid True if the proof structure is valid
     * @return subtreeProofCount Number of nodes in the subtree proof
     * @return followingHashesCount Number of nodes in the following hashes
     * @return hasPreHash Flag indicating if preHash is present
     * @return minRequiredNodes Minimum required nodes based on the counts
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
            uint256 minRequiredNodes
        )
    {
        // Extract counts from packed data
        (subtreeProofCount, followingHashesCount, hasPreHash) = extractCounts(proof.counts);

        // Calculate minimum required nodes
        minRequiredNodes = subtreeProofCount + followingHashesCount;
        if (hasPreHash) {
            minRequiredNodes += 1;
        }

        // If hasPreHash is true but no nodes are provided, this is invalid
        if (hasPreHash && proof.nodes.length == 0) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, minRequiredNodes);
        }

        // Check if we have enough nodes
        if (proof.nodes.length < minRequiredNodes) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, minRequiredNodes);
        }

        // Check for inconsistent hasPreHash flag
        if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, minRequiredNodes);
        }

        // Check for excess nodes when hasPreHash is false
        if (
            !hasPreHash && proof.nodes.length > (subtreeProofCount + followingHashesCount)
                && subtreeProofCount + followingHashesCount > 0
        ) {
            return (false, subtreeProofCount, followingHashesCount, hasPreHash, minRequiredNodes);
        }

        // All basic structural validation passed
        return (true, subtreeProofCount, followingHashesCount, hasPreHash, minRequiredNodes);
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
            uint256 minRequiredNodes
        ) = _validateProofStructure(proof);

        // If validation fails, revert with appropriate reason
        if (!isValid) {
            if (hasPreHash && proof.nodes.length == 0) {
                revert IUnhingedMerkleTree.HasPreHashButEmptyNodes();
            }

            if (proof.nodes.length < minRequiredNodes) {
                revert IUnhingedMerkleTree.InvalidNodeArrayLength(minRequiredNodes, proof.nodes.length);
            }

            if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
                revert IUnhingedMerkleTree.InconsistentPreHashFlag(true, bytes32(0));
            }

            if (
                !hasPreHash && proof.nodes.length > (subtreeProofCount + followingHashesCount)
                    && subtreeProofCount + followingHashesCount > 0
            ) {
                revert IUnhingedMerkleTree.InvalidNodeArrayLength(
                    subtreeProofCount + followingHashesCount, proof.nodes.length
                );
            }

            // Catch-all for any other validation issues
            revert IUnhingedMerkleTree.InvalidParameters();
        }

        return _computeRoot(proof, leaf, subtreeProofCount, followingHashesCount, hasPreHash);
    }

    /**
     * @dev Computes the unhinged root from validated components
     * @param proof The unhinged proof structure (pre-validated)
     * @param leaf The leaf node to verify
     * @param subtreeProofCount Number of nodes in the subtree proof
     * @param followingHashesCount Number of nodes in the following hashes
     * @param hasPreHash Flag indicating if preHash is present
     * @return The calculated unhinged root
     */
    function _computeRoot(
        IUnhingedMerkleTree.UnhingedProof calldata proof,
        bytes32 leaf,
        uint120 subtreeProofCount,
        uint120 followingHashesCount,
        bool hasPreHash
    ) private pure returns (bytes32) {
        // Extract proof components and establish starting points
        bytes32 calculatedRoot;
        uint256 subtreeProofStartIndex = hasPreHash ? 1 : 0;

        // Calculate the subtree root directly using the original array with an offset
        bytes32 subtreeRoot =
            verifyBalancedSubtreeWithOffset(proof.nodes, subtreeProofStartIndex, subtreeProofCount, leaf);

        // Calculate the unhinged chain - either start with preHash or use subtreeRoot directly
        if (hasPreHash) {
            calculatedRoot = hashLink(proof.nodes[0], subtreeRoot);
        } else {
            calculatedRoot = subtreeRoot;
        }

        // Add all following chain hashes
        uint256 followingHashesStartIndex = subtreeProofStartIndex + subtreeProofCount;
        for (uint256 i = 0; i < followingHashesCount; i++) {
            calculatedRoot = hashLink(calculatedRoot, proof.nodes[followingHashesStartIndex + i]);
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

        // Determine array size needed
        uint256 nodesArraySize = subtreeProof.length + followingHashes.length + (hasPreHash ? 1 : 0);

        // Create the combined nodes array
        bytes32[] memory nodes = new bytes32[](nodesArraySize);

        // We still need to create a combined array, but we can use a more efficient method
        uint256 currentIndex = 0;

        // 1. Add preHash if present
        if (hasPreHash) {
            nodes[currentIndex++] = preHash;
        }

        // 2. Add subtree proof nodes
        for (uint256 i = 0; i < subtreeProof.length; i++) {
            nodes[currentIndex++] = subtreeProof[i];
        }

        // 3. Add following hash nodes
        for (uint256 i = 0; i < followingHashes.length; i++) {
            nodes[currentIndex++] = followingHashes[i];
        }

        // 4. Pack the counts with the hasPreHash flag
        bytes32 counts = packCounts(uint120(subtreeProof.length), uint120(followingHashes.length), hasPreHash);

        // 5. Create and return the optimized proof
        optimizedProof = IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });
    }
}
