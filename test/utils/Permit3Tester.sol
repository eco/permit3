// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Permit3.sol";
import "../../src/interfaces/IUnhingedMerkleTree.sol";

/**
 * @title Permit3Tester
 * @notice Helper contract to expose internal functions for testing
 */
contract Permit3Tester is Permit3 {
    /**
     * @notice Exposes the internal calculateUnhingedRoot function for testing
     */
    function calculateUnhingedRoot(
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof memory proof
    ) external pure returns (bytes32) {
        return _calculateUnhingedRoot(leaf, proof);
    }

    /**
     * @notice Exposes the internal verifyUnhingedProof function for testing
     */
    function verifyUnhingedProof(
        bytes32 leaf,
        IUnhingedMerkleTree.UnhingedProof memory proof
    ) external pure returns (bool) {
        return _verifyUnhingedProof(leaf, proof);
    }

    /**
     * @notice Exposes the internal verifyBalancedSubtree function for testing
     */
    function verifyBalancedSubtree(bytes32 leaf, bytes32[] memory proof) external pure returns (bytes32) {
        return _verifyBalancedSubtree(leaf, proof);
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
