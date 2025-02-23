// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title INonceManager
 * @notice Interface for managing non-sequential nonces used in permit operations
 */
interface INonceManager {
    /// @notice Thrown when a signature has expired
    error SignatureExpired();

    /// @notice Thrown when a signature is invalid
    error InvalidSignature();

    /// @notice Thrown when a nonce has already been used
    error NonceAlreadyUsed();

    /// @notice Thrown when a chain ID is invalid
    error WrongChainId();

    /**
     * @notice Nonce invalidation parameters for a specific chain
     * @param chainId Target chain identifier
     * @param noncesToInvalidate Array of nonces to mark as used
     */
    struct NoncesToInvalidate {
        uint64 chainId;
        uint48[] noncesToInvalidate;
    }

    /**
     * @notice Struct for cross-chain nonce invalidation proof
     * @param preHash Hash of previous chain invalidations
     * @param invalidations Current chain invalidation data
     * @param followingHashes Subsequent chain invalidation hashes
     */
    struct CancelPermit3Proof {
        bytes32 preHash;
        NoncesToInvalidate invalidations;
        bytes32[] followingHashes;
    }

    /**
     * @notice Export EIP-712 domain separator
    * @return bytes32 domain separator hash
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @notice Check if a nonce has been used
     * @param owner Address that owns the nonce
     * @param nonce Nonce value to check
     * @return true if nonce has been used
     */
    function isNonceUsed(address owner, uint48 nonce) external view returns (bool);

    /**
     * @notice Mark multiple nonces as used
     * @param noncesToInvalidate Array of nonces to invalidate
     */
    function invalidateNonces(
        uint48[] calldata noncesToInvalidate
    ) external;

    /**
     * @notice Mark nonces as used with signature authorization
     * @param owner Token owner address
     * @param deadline Signature expiration timestamp
     * @param invalidations Chain-specific nonce invalidation data
     * @param signature EIP-712 signature authorizing the invalidation
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        NoncesToInvalidate memory invalidations,
        bytes calldata signature
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
