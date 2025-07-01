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
    error WrongChainId(uint256 expected, uint256 provided);

    /// @notice Thrown when a witness type string is invalid
    error InvalidWitnessTypeString();


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
     * @notice Struct for unhinged nonce invalidation proof
     * @param invalidations Current chain invalidation data
     * @param unhingedProof UnhingedProof structure for verification
     */
    struct UnhingedCancelPermitProof {
        NoncesToInvalidate invalidations;
        bytes32 unhingedRoot;
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
    function isNonceUsed(address owner, bytes32 salt) external view returns (bool);

    /**
     * @notice Mark multiple nonces as used
     * @param salts Array of salts to invalidate
     */
    function invalidateNonces(
        bytes32[] calldata salts
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
     * @notice Cross-chain nonce invalidation using the Unhinged Merkle Tree approach
     * @param owner Token owner address
     * @param deadline Signature expiration timestamp
     * @param proof Unhinged invalidation proof
     * @param signature EIP-712 signature authorizing the invalidation
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        UnhingedCancelPermitProof memory proof,
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
