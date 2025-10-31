// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/lib/TreeNodeLib.sol";

/**
 * @title TreeNodeLibTester
 * @notice Test helper contract that exposes TreeNodeLib internal functions
 * @dev Wraps all TreeNodeLib functions as external pure functions for testing
 */
contract TreeNodeLibTester {
    /**
     * @notice Expose combineLeafAndLeaf for testing
     * @param typehash EIP-712 typehash to use
     * @param leaf1 First leaf hash
     * @param leaf2 Second leaf hash
     * @return bytes32 Combined hash
     */
    function combineLeafAndLeaf(
        bytes32 typehash,
        bytes32 leaf1,
        bytes32 leaf2
    ) external pure returns (bytes32) {
        return TreeNodeLib.combineLeafAndLeaf(typehash, leaf1, leaf2);
    }

    /**
     * @notice Expose combineNodeAndNode for testing
     * @param typehash EIP-712 typehash to use
     * @param node1 First node hash
     * @param node2 Second node hash
     * @return bytes32 Combined hash
     */
    function combineNodeAndNode(
        bytes32 typehash,
        bytes32 node1,
        bytes32 node2
    ) external pure returns (bytes32) {
        return TreeNodeLib.combineNodeAndNode(typehash, node1, node2);
    }

    /**
     * @notice Expose combineNodeAndLeaf for testing
     * @param typehash EIP-712 typehash to use
     * @param nodeHash Node hash
     * @param leafHash Leaf hash
     * @return bytes32 Combined hash
     */
    function combineNodeAndLeaf(
        bytes32 typehash,
        bytes32 nodeHash,
        bytes32 leafHash
    ) external pure returns (bytes32) {
        return TreeNodeLib.combineNodeAndLeaf(typehash, nodeHash, leafHash);
    }

    /**
     * @notice Expose computeTreeHash for testing
     * @param typehash EIP-712 typehash to use
     * @param proofStructure Compact encoding (position + type flags)
     * @param proof Array of sibling hashes
     * @param currentLeaf Current leaf hash
     * @return bytes32 Reconstructed tree hash
     */
    function computeTreeHash(
        bytes32 typehash,
        bytes32 proofStructure,
        bytes32[] calldata proof,
        bytes32 currentLeaf
    ) external pure returns (bytes32) {
        return TreeNodeLib.computeTreeHash(typehash, proofStructure, proof, currentLeaf);
    }
}
