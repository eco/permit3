// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TreeNodeLibTester.sol";

/**
 * @title PermitNodeLibTester
 * @notice Helper contract to expose PermitNode-specific functions for testing
 * @dev Thin wrapper around TreeNodeLibTester that maintains backward compatibility
 *      by providing the same external API while using the generic TreeNodeLib internally
 */
contract PermitNodeLibTester {
    TreeNodeLibTester internal treeNodeTester;

    /**
     * @dev EIP-712 typehash for PermitNode structure
     * Must match the typehash used in Permit3.sol
     */
    bytes32 private constant _PERMIT_NODE_TYPEHASH = keccak256(
        "PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)"
    );

    constructor() {
        treeNodeTester = new TreeNodeLibTester();
    }

    /**
     * @notice Expose PERMIT_NODE_TYPEHASH constant
     */
    function PERMIT_NODE_TYPEHASH() external pure returns (bytes32) {
        return _PERMIT_NODE_TYPEHASH;
    }

    /**
     * @notice Expose EMPTY_ARRAY_HASH constant
     */
    function EMPTY_ARRAY_HASH() external pure returns (bytes32) {
        return keccak256("");
    }

    /**
     * @notice Expose _combinePermitAndPermit function
     */
    function combinePermitAndPermit(
        bytes32 permit1,
        bytes32 permit2
    ) external view returns (bytes32) {
        return treeNodeTester.combineLeafAndLeaf(_PERMIT_NODE_TYPEHASH, permit1, permit2);
    }

    /**
     * @notice Expose _combineNodeAndNode function
     */
    function combineNodeAndNode(
        bytes32 node1,
        bytes32 node2
    ) external view returns (bytes32) {
        return treeNodeTester.combineNodeAndNode(_PERMIT_NODE_TYPEHASH, node1, node2);
    }

    /**
     * @notice Expose _combineNodeAndPermit function
     */
    function combineNodeAndPermit(
        bytes32 nodeHash,
        bytes32 permitHash
    ) external view returns (bytes32) {
        return treeNodeTester.combineNodeAndLeaf(_PERMIT_NODE_TYPEHASH, nodeHash, permitHash);
    }

    /**
     * @notice Expose _reconstructPermitNodeHash function
     */
    function reconstructPermitNodeHash(
        bytes32 proofStructure,
        bytes32[] calldata proof,
        bytes32 currentChainHash
    ) external view returns (bytes32) {
        return treeNodeTester.computeTreeHash(_PERMIT_NODE_TYPEHASH, proofStructure, proof, currentChainHash);
    }
}
