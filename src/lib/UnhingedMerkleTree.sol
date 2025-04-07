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
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof memory proof,
        bytes32 unhingedRoot
    ) internal pure returns (bool) {
        // Extract counts from packed data
        (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) = extractCounts(proof.counts);
        
        // Calculate minimum required nodes
        uint256 minRequiredNodes = subtreeProofCount + followingHashesCount;
        if (hasPreHash) {
            minRequiredNodes += 1;
        }
        
        // Enhanced validation for the nodes array and hasPreHash flag
        if (hasPreHash && proof.nodes.length == 0) {
            // If hasPreHash is true but the nodes array is empty, that's an error
            revert IUnhingedMerkleTree.HasPreHashButEmptyNodes();
        }
        
        // Verify array size is sufficient
        if (proof.nodes.length < minRequiredNodes) {
            revert IUnhingedMerkleTree.InvalidNodeArrayLength(minRequiredNodes, proof.nodes.length);
        }
        
        // Verify consistency between hasPreHash flag and preHash value when present
        if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
            // Warning: hasPreHash is true but preHash is zero, which is suspicious
            revert IUnhingedMerkleTree.InconsistentPreHashFlag(true, bytes32(0));
        }
        
        // Extract proof components and establish starting points
        bytes32 calculatedRoot;
        uint256 subtreeProofStartIndex;
        
        if (hasPreHash) {
            // If we have a preHash, use it as the starting point
            calculatedRoot = proof.nodes[0];
            subtreeProofStartIndex = 1;
        } else {
            // If hasPreHash flag is false, we don't need calculatedRoot yet
            // We'll use subtreeRoot directly as our starting point after verification
            subtreeProofStartIndex = 0;
        }
        
        // Create subtree proof array in memory
        bytes32[] memory subtreeProof = new bytes32[](subtreeProofCount);
        for (uint256 i = 0; i < subtreeProofCount; i++) {
            subtreeProof[i] = proof.nodes[subtreeProofStartIndex + i];
        }
        
        // First verify the balanced subtree proof
        bytes32 subtreeRoot = verifyBalancedSubtree(leaf, subtreeProof);
        
        // Then recalculate the unhinged chain
        if (hasPreHash) {
            // If we have a preHash, hash it with the subtree root
            calculatedRoot = keccak256(abi.encodePacked(calculatedRoot, subtreeRoot));
        } else {
            // If no preHash, the subtree root is our starting point
            calculatedRoot = subtreeRoot;
        }
        
        // Add all following chain hashes
        uint256 followingHashesStartIndex = subtreeProofStartIndex + subtreeProofCount;
        for (uint256 i = 0; i < followingHashesCount; i++) {
            calculatedRoot = keccak256(abi.encodePacked(
                calculatedRoot, 
                proof.nodes[followingHashesStartIndex + i]
            ));
        }
        
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
    function extractCounts(bytes32 counts) internal pure returns (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) {
        uint256 value = uint256(counts);
        
        // Extract the different parts from the packed value
        subtreeProofCount = uint120(value >> 136);  // First 120 bits
        followingHashesCount = uint120((value >> 16) & ((1 << 120) - 1));  // Next 120 bits
        // Skip 15 bits reserved for future use
        hasPreHash = (value & 1) == 1;  // Last bit
    }
    
    /**
     * @dev Pack counts into a single bytes32
     * @param subtreeProofCount Number of nodes in the subtree proof
     * @param followingHashesCount Number of nodes in the following hashes
     * @param hasPreHash Flag indicating if preHash is present
     * @return counts The packed counts value
     */
    function packCounts(uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) internal pure returns (bytes32 counts) {
        // Make sure the values fit within the bit ranges
        require(subtreeProofCount < (1 << 120), "SubtreeProofCount overflow");
        require(followingHashesCount < (1 << 120), "FollowingHashesCount overflow");
        
        // Pack the values
        uint256 packedValue = 0;
        packedValue |= uint256(subtreeProofCount) << 136;  // First 120 bits
        packedValue |= uint256(followingHashesCount) << 16;  // Next 120 bits
        // Bits 1-15 are reserved for future use (zeros)
        if (hasPreHash) {
            packedValue |= 1;  // Set the last bit if preHash is present
        }
        
        counts = bytes32(packedValue);
    }
    
    /**
     * @dev Verifies a standard Merkle proof for a balanced subtree
     * @param leaf The leaf node being proven
     * @param proof The Merkle proof (sibling hashes)
     * @return The calculated root of the balanced subtree
     */
    function verifyBalancedSubtree(
        bytes32 leaf,
        bytes32[] memory proof
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
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
    function createUnhingedRoot(bytes32[] memory subtreeRoots) internal pure returns (bytes32) {
        if (subtreeRoots.length == 0) {
            return bytes32(0);
        }
        
        bytes32 unhingedRoot = subtreeRoots[0];
        
        for (uint256 i = 1; i < subtreeRoots.length; i++) {
            unhingedRoot = keccak256(abi.encodePacked(unhingedRoot, subtreeRoots[i]));
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
     * @dev Calculates the unhinged root from a leaf and proof with validation checks
     * @param leaf The leaf node to calculate from
     * @param proof The unhinged proof structure
     * @return The calculated unhinged root
     * @notice This function performs validation checks on the proof structure
     *         before calculating the root. It supports the hasPreHash optimization.
     */
    function calculateRoot(
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof memory proof
    ) internal pure returns (bytes32) {
        // Extract counts from packed data
        (uint120 subtreeProofCount, uint120 followingHashesCount, bool hasPreHash) = extractCounts(proof.counts);
        
        // Calculate minimum required nodes based on whether preHash is present
        uint256 minRequiredNodes = subtreeProofCount + followingHashesCount;
        if (hasPreHash) {
            minRequiredNodes += 1; // Add 1 for the preHash node when hasPreHash=true
        }
        
        // Enhanced validation for the nodes array and hasPreHash flag
        if (hasPreHash && proof.nodes.length == 0) {
            // If hasPreHash is true but nodes array is empty, that's invalid
            revert IUnhingedMerkleTree.HasPreHashButEmptyNodes();
        }
        
        // Check array length matches what we expect based on counts
        if (proof.nodes.length < minRequiredNodes) {
            revert IUnhingedMerkleTree.InvalidNodeArrayLength(minRequiredNodes, proof.nodes.length);
        }
        
        // Verify consistency between hasPreHash flag and preHash value
        if (hasPreHash && proof.nodes.length > 0 && proof.nodes[0] == bytes32(0)) {
            // hasPreHash is true but preHash is zero, which is inconsistent and suspicious
            revert IUnhingedMerkleTree.InconsistentPreHashFlag(true, bytes32(0));
        }
        
        // Additional validation to catch suspicious cases where hasPreHash is false but there are extra nodes
        if (!hasPreHash && proof.nodes.length > (subtreeProofCount + followingHashesCount) && 
            subtreeProofCount + followingHashesCount > 0) {
            // This is a potential error case where there are more nodes than needed
            revert IUnhingedMerkleTree.InvalidNodeArrayLength(
                subtreeProofCount + followingHashesCount, 
                proof.nodes.length
            );
        }
        
        // Extract proof components and establish starting points
        bytes32 calculatedRoot;
        uint256 subtreeProofStartIndex;
        
        if (hasPreHash) {
            // If hasPreHash is true, use the preHash as starting point
            calculatedRoot = proof.nodes[0];
            subtreeProofStartIndex = 1;
        } else {
            // If hasPreHash is false, we'll start with the subtree root directly
            subtreeProofStartIndex = 0;
        }
        
        // Create subtree proof array
        bytes32[] memory subtreeProof = new bytes32[](subtreeProofCount);
        for (uint256 i = 0; i < subtreeProofCount; i++) {
            subtreeProof[i] = proof.nodes[subtreeProofStartIndex + i];
        }
        
        // Calculate the subtree root
        bytes32 subtreeRoot = verifyBalancedSubtree(leaf, subtreeProof);
        
        // Calculate the unhinged chain - either start with preHash or use subtreeRoot directly
        if (hasPreHash) {
            calculatedRoot = keccak256(abi.encodePacked(calculatedRoot, subtreeRoot));
        } else {
            calculatedRoot = subtreeRoot;
        }
        
        // Add all following chain hashes
        uint256 followingHashesStartIndex = subtreeProofStartIndex + subtreeProofCount;
        for (uint256 i = 0; i < followingHashesCount; i++) {
            calculatedRoot = keccak256(abi.encodePacked(
                calculatedRoot, 
                proof.nodes[followingHashesStartIndex + i]
            ));
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
        
        // 1. Create the combined nodes array (size depends on whether preHash is included)
        uint256 nodesArraySize = subtreeProof.length + followingHashes.length;
        if (hasPreHash) {
            nodesArraySize += 1;
        }
        
        bytes32[] memory nodes = new bytes32[](nodesArraySize);
        
        // 2. Add preHash if present
        uint256 subtreeStartIndex = 0;
        if (hasPreHash) {
            nodes[0] = preHash;
            subtreeStartIndex = 1;
        }
        
        // 3. Add subtree proof nodes
        for (uint i = 0; i < subtreeProof.length; i++) {
            nodes[subtreeStartIndex + i] = subtreeProof[i];
        }
        
        // 4. Add following hash nodes
        for (uint i = 0; i < followingHashes.length; i++) {
            nodes[subtreeStartIndex + subtreeProof.length + i] = followingHashes[i];
        }
        
        // 5. Pack the counts with the hasPreHash flag
        bytes32 counts = packCounts(
            uint120(subtreeProof.length),
            uint120(followingHashes.length),
            hasPreHash
        );
        
        // 6. Create the optimized proof
        optimizedProof = IUnhingedMerkleTree.UnhingedProof({
            nodes: nodes,
            counts: counts
        });
    }
}