// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IUnhingedMerkleTree
 * @notice Interface for Unhinged Merkle Tree - a standard merkle tree structure for cross-chain proofs
 * @dev The Unhinged Merkle Tree uses standard merkle tree verification with ordered hashing
 */
interface IUnhingedMerkleTree {
    /**
     * @notice Simple merkle proof structure
     * @param nodes Array of sibling hashes forming the merkle proof path from leaf to root
     * @dev Uses standard merkle tree verification with ordered hashing (smaller value first)
     */
    struct UnhingedProof {
        bytes32[] nodes;
    }

    /**
     * @notice Error when the merkle proof verification fails
     */
    error InvalidMerkleProof();

    /**
     * @notice Error when input parameters are invalid
     */
    error InvalidParameters();
}
