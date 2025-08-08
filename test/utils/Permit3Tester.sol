// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Permit3.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title Permit3Tester
 * @notice Helper contract to expose internal functions for testing
 */
contract Permit3Tester is Permit3 {
    /**
     * @notice Exposes the MerkleProof.processProof function for testing
     */
    function calculateUnhingedRoot(bytes32 leaf, bytes32[] calldata unhingedProof) external pure returns (bytes32) {
        return MerkleProof.processProof(unhingedProof, leaf);
    }

    /**
     * @notice Verifies an unhinged proof structure
     */
    function verifyUnhingedProof(
        bytes32 leaf,
        bytes32[] calldata unhingedProof,
        bytes32 expectedRoot
    ) external pure returns (bool) {
        return MerkleProof.verify(unhingedProof, expectedRoot, leaf);
    }

    /**
     * @notice Exposes the internal hashChainPermits function for testing
     */
    // Function removed as it's now directly available from Permit3
}
