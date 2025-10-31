// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit } from "./IPermit.sol";

/**
 * @title INonceManager
 * @notice Interface for managing non-sequential nonces used in permit operations
 */
interface INonceManager is IPermit {
    /**
     * @notice Error when the merkle proof verification fails
     */
    error InvalidMerkleProof();

    /**
     * @notice Error when input parameters are invalid
     */
    error InvalidParameters();

    /**
     * @notice Thrown when a signature has expired
     * @param deadline The timestamp when the signature expired
     * @param currentTimestamp The current block timestamp
     */
    error SignatureExpired(uint48 deadline, uint48 currentTimestamp);

    /**
     * @notice Thrown when a signature is invalid
     * @param signer The address whose signature failed verification
     */
    error InvalidSignature(address signer);

    /**
     * @notice Thrown when a nonce has already been used
     * @param owner The owner of the nonce
     * @param salt The salt value that was already used
     */
    error NonceAlreadyUsed(address owner, bytes32 salt);

    /**
     * @notice Thrown when a chain ID is invalid
     */
    error WrongChainId(uint256 expected, uint256 provided);

    /**
     * @notice Thrown when a witness type string is invalid
     * @param witnessTypeString The invalid witness type string provided
     */
    error InvalidWitnessTypeString(string witnessTypeString);

    /**
     * @notice Emitted when a nonce is invalidated
     * @param owner The owner of the nonce
     * @param salt The nonce salt that was invalidated
     */
    event NonceInvalidated(address indexed owner, bytes32 indexed salt);

    /**
     * @notice Nonce invalidation parameters for a specific chain
     * @param chainId Target chain identifier
     * @param salts Array of salts to mark as used
     */
    struct NoncesToInvalidate {
        uint64 chainId;
        bytes32[] salts;
    }

    /**
     * @notice Nested structure for batch nonce invalidation with UI transparency
     * @dev Similar to PermitNode - enables tree-based nonce invalidation
     * @dev Binary tree structure where leaves are NoncesToInvalidate (chain-specific nonce lists)
     * @param nodes Child nonce tree nodes (nested structures)
     * @param nonces Leaf invalidations (NoncesToInvalidate for each chain)
     */
    struct NonceNode {
        NonceNode[] nodes;
        NoncesToInvalidate[] nonces;
    }

    /**
     * @notice Signature data for nonce invalidation operations
     * @dev Parallel to IPermit3.Signature but without salt and timestamp fields
     * @param owner Address that owns the nonces being invalidated
     * @param deadline Timestamp after which signature expires
     * @param signature EIP-712 signature bytes
     */
    struct NonceSignature {
        address owner;
        uint48 deadline;
        bytes signature;
    }

    /**
     * @notice Input struct for tree-based nonce invalidation containing tree structure data
     * @dev Parallel to IPermit3.PermitTree struct
     * @param currentChainInvalidations Nonces to invalidate for the current chain
     * @param proofStructure Compact tree encoding (position + type flags)
     * @param proof Array of sibling hashes for tree reconstruction
     */
    struct NonceTree {
        NoncesToInvalidate currentChainInvalidations;
        bytes32 proofStructure;
        bytes32[] proof;
    }

    /**
     * @notice Export EIP-712 domain separator
     * @return bytes32 domain separator hash
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @notice Check if a nonce has been used
     * @param owner Address that owns the nonce
     * @param salt Salt value to check
     * @return true if nonce has been used
     */
    function isNonceUsed(
        address owner,
        bytes32 salt
    ) external view returns (bool);

    /**
     * @notice Mark multiple nonces as used
     * @param salts Array of salts to invalidate
     */
    function invalidateNonces(
        bytes32[] calldata salts
    ) external;

    /**
     * @notice Mark nonces as used with signature authorization
     * @param salts Array of nonce salts to invalidate
     * @param sig Signature data (owner, deadline, signature)
     */
    function invalidateNonces(
        bytes32[] calldata salts,
        NonceSignature calldata sig
    ) external;

    /**
     * @notice Invalidate multiple nonces using tree structure with UI transparency
     * @dev User signs complete NonceNode showing all nonces being invalidated
     * @param tree NonceTree containing proofStructure, currentChainInvalidations, and proof
     * @param sig Signature data (owner, deadline, signature)
     */
    function invalidateNonces(
        NonceTree calldata tree,
        NonceSignature calldata sig
    ) external;

    /**
     * @notice Generate hash for nonce invalidation data
     * @param invalidations Nonce invalidation parameters
     * @return bytes32 EIP-712 compatible hash
     */
    function hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) external pure returns (bytes32);
}
