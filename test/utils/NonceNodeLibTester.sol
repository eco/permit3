// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TreeNodeLibTester.sol";

/**
 * @title NonceNodeLibTester
 * @notice Helper contract to expose NonceNodeLib internal functions for testing
 * @dev This contract is a thin wrapper around TreeNodeLibTester, maintaining backward compatibility
 * @dev Provides the same external API as before, but delegates to the generic TreeNodeLib implementation
 */
contract NonceNodeLibTester {
    TreeNodeLibTester internal treeNodeTester;

    /**
     * @dev EIP-712 typehash for NonceNode structure
     * Must match the typehash used in NonceManager.sol
     */
    bytes32 private constant _NONCE_NODE_TYPEHASH = keccak256("NonceNode(NonceNode[] nodes,bytes32[] nonces)");

    constructor() {
        treeNodeTester = new TreeNodeLibTester();
    }

    /**
     * @notice Expose NONCE_NODE_TYPEHASH constant
     */
    function NONCE_NODE_TYPEHASH() external pure returns (bytes32) {
        return _NONCE_NODE_TYPEHASH;
    }

    /**
     * @notice Expose EMPTY_ARRAY_HASH constant
     */
    function EMPTY_ARRAY_HASH() external pure returns (bytes32) {
        return keccak256("");
    }

    /**
     * @notice Expose _combineNonceAndNonce function
     */
    function combineNonceAndNonce(
        bytes32 nonce1,
        bytes32 nonce2
    ) external view returns (bytes32) {
        return treeNodeTester.combineLeafAndLeaf(_NONCE_NODE_TYPEHASH, nonce1, nonce2);
    }

    /**
     * @notice Expose _combineNodeAndNode function
     */
    function combineNodeAndNode(
        bytes32 node1,
        bytes32 node2
    ) external view returns (bytes32) {
        return treeNodeTester.combineNodeAndNode(_NONCE_NODE_TYPEHASH, node1, node2);
    }

    /**
     * @notice Expose _combineNodeAndNonce function
     */
    function combineNodeAndNonce(
        bytes32 nodeHash,
        bytes32 nonceHash
    ) external view returns (bytes32) {
        return treeNodeTester.combineNodeAndLeaf(_NONCE_NODE_TYPEHASH, nodeHash, nonceHash);
    }

    /**
     * @notice Expose _reconstructNonceNodeHash function
     */
    function reconstructNonceNodeHash(
        bytes32 proofStructure,
        bytes32[] calldata proof,
        bytes32 currentNonce
    ) external view returns (bytes32) {
        return treeNodeTester.computeTreeHash(_NONCE_NODE_TYPEHASH, proofStructure, proof, currentNonce);
    }
}
