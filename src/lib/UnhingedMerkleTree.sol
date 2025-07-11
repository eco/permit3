// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUnhingedMerkleTree } from "../interfaces/IUnhingedMerkleTree.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title UnhingedMerkleTree
 * @notice A library implementing Unhinged Merkle Tree structure for cross-chain proofs
 * @dev Uses OpenZeppelin's MerkleProof library for standard merkle tree verification
 */
library UnhingedMerkleTree {
    /**
     * @dev Verifies an Unhinged Merkle proof
     * @param unhingedProof The merkle proof - array of sibling hashes
     * @param unhingedRoot The expected root of the merkle tree
     * @param leaf The leaf node being proven
     * @return True if the proof is valid, false otherwise
     */
    function verify(
        bytes32[] calldata unhingedProof,
        bytes32 unhingedRoot,
        bytes32 leaf
    ) internal pure returns (bool) {
        return MerkleProof.verify(unhingedProof, unhingedRoot, leaf);
    }

    /**
     * @dev Calculates the merkle root from a leaf and proof
     * @param unhingedProof The merkle proof - array of sibling hashes
     * @param leaf The leaf node to calculate from
     * @return The calculated merkle root
     */
    function calculateRoot(
        bytes32[] calldata unhingedProof,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        return MerkleProof.processProof(unhingedProof, leaf);
    }

    /**
     * @dev Calculates the merkle root from a leaf and proof nodes
     * @param leaf The leaf node to calculate from
     * @param proofNodes Array of sibling hashes in the merkle tree
     * @return The calculated merkle root
     */
    function calculateRoot(bytes32 leaf, bytes32[] memory proofNodes) internal pure returns (bytes32) {
        return MerkleProof.processProof(proofNodes, leaf);
    }

    /**
     * @dev Verifies a merkle proof (alternative function for compatibility)
     * @param root The expected merkle root
     * @param leaf The leaf being proven
     * @param proof Array of sibling hashes
     * @return True if proof is valid
     */
    function verifyProof(bytes32 root, bytes32 leaf, bytes32[] memory proof) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }
}
