// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Permit3.sol";
import "../../src/interfaces/IUnhingedMerkleTree.sol";
import "../../src/lib/UnhingedMerkleTree.sol";

/**
 * @title Permit3Tester
 * @notice Helper contract to expose internal functions for testing
 */
contract Permit3Tester is Permit3 {
    using UnhingedMerkleTree for bytes32;
    using UnhingedMerkleTree for IUnhingedMerkleTree.UnhingedProof;
    using UnhingedMerkleTree for bytes32[];
    /**
     * @notice Exposes the UnhingedMerkleTree.calculateRoot function for testing
     */

    function calculateUnhingedRoot(
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof memory proof
    ) external pure returns (bytes32) {
        return proof.calculateRoot(leaf);
    }

    /**
     * @notice Exposes the UnhingedMerkleTree.verifyProofStructure function for testing
     */
    function verifyUnhingedProof(
        bytes32, // leaf: unused but kept for API compatibility with tests
        IUnhingedMerkleTree.UnhingedProof memory proof
    ) external pure returns (bool) {
        return proof.verifyProofStructure();
    }

    /**
     * @notice Exposes the UnhingedMerkleTree.verifyBalancedSubtree function for testing
     */
    function verifyBalancedSubtree(bytes32 leaf, bytes32[] memory proof) external pure returns (bytes32) {
        return proof.verifyBalancedSubtree(leaf);
    }

    /**
     * @notice Exposes the internal hashChainPermits function for testing
     */
    function hashChainPermits(
        ChainPermits memory permits
    ) external pure returns (bytes32) {
        return _hashChainPermits(permits);
    }
}
