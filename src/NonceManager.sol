// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { INonceManager } from "./interfaces/INonceManager.sol";
import { EIP712 } from "./lib/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NonceManager
 * @notice Manages non-sequential nonces for replay protection in the Permit3 system
 * @dev Key features:
 * - Non-sequential nonces for concurrent operation support
 * - Signature-based nonce invalidation
 * - Cross-chain nonce management
 * - EIP-712 compliant signatures
 */
abstract contract NonceManager is INonceManager, EIP712 {
    using ECDSA for bytes32;

    /**
     * @notice Maps owner address to their used nonces
     * @dev Status values: 0 = unused, 1 = used
     * @dev Non-sequential nonces allow parallel operations without conflicts
     */
    mapping(address => mapping(bytes32 => uint256)) internal usedNonces;

    /**
     * @notice EIP-712 typehash for nonce invalidation
     * @dev Includes chainId for cross-chain replay protection
     */
    bytes32 public constant NONCES_TO_INVALIDATE_TYPEHASH =
        keccak256("NoncesToInvalidate(uint256 chainId,bytes32[] salts)");

    /**
     * @notice EIP-712 typehash for invalidation signatures
     * @dev Includes owner, deadline, and unhinged root for batch operations
     */
    bytes32 public constant SIGNED_CANCEL_PERMIT3_TYPEHASH =
        keccak256("SignedCancelPermit3(address owner,uint256 deadline,bytes32 unhingedRoot)");

    /**
     * @notice Initialize EIP-712 domain separator
     * @param name Contract name for EIP-712 domain
     * @param version Contract version for EIP-712 domain
     */
    constructor(string memory name, string memory version) EIP712(name, version) { }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Check if a specific nonce has been used
     * @param owner The address to check nonces for
     * @param salt The salt value to verify
     * @return True if nonce has been used, false otherwise
     */
    function isNonceUsed(address owner, bytes32 salt) external view returns (bool) {
        return usedNonces[owner][salt] == 1;
    }

    /**
     * @notice Directly invalidate multiple nonces without signature
     * @param salts Array of salts to mark as used
     */
    function invalidateNonces(
        bytes32[] calldata salts
    ) external {
        uint256 length = salts.length;

        for (uint256 i = 0; i < length; i++) {
            usedNonces[msg.sender][salts[i]] = 1;
        }
    }

    /**
     * @notice Invalidate nonces using a signed message
     * @param owner Address that signed the invalidation
     * @param deadline Timestamp after which signature is invalid
     * @param invalidations Struct containing chain ID and nonces to invalidate
     * @param signature EIP-712 signature authorizing invalidation
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        NoncesToInvalidate memory invalidations,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(invalidations.chainId == block.chainid, WrongChainId(block.chainid, invalidations.chainId));

        bytes32 signedHash = keccak256(
            abi.encode(SIGNED_CANCEL_PERMIT3_TYPEHASH, owner, deadline, hashNoncesToInvalidate(invalidations))
        );

        bytes32 digest = _hashTypedDataV4(signedHash);
        require(digest.recover(signature) == owner, InvalidSignature());

        _processNonceInvalidation(owner, invalidations);
    }

    /**
     * @notice Cross-chain nonce invalidation using the Unhinged Merkle Tree approach
     * @param owner Token owner
     * @param deadline Signature expiration
     * @param proof Unhinged Merkle Tree invalidation proof
     * @param signature Authorization signature
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        UnhingedCancelPermitProof memory proof,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(proof.invalidations.chainId == block.chainid, WrongChainId(block.chainid, proof.invalidations.chainId));

        bytes32 signedHash = keccak256(abi.encode(SIGNED_CANCEL_PERMIT3_TYPEHASH, owner, deadline, proof.unhingedRoot));

        bytes32 digest = _hashTypedDataV4(signedHash);
        require(digest.recover(signature) == owner, InvalidSignature());

        _processNonceInvalidation(owner, proof.invalidations);
    }

    /**
     * @notice Generate EIP-712 hash for nonce invalidation data
     * @param invalidations Struct containing chain ID and nonces
     * @return bytes32 Hash of the invalidation data
     */
    function hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(NONCES_TO_INVALIDATE_TYPEHASH, invalidations.chainId, invalidations.salts));
    }

    /**
     * @notice Process batch nonce invalidation
     * @dev Marks all nonces in the batch as used (1)
     * @param owner Token owner requesting invalidation
     * @param invalidations Nonces to invalidate with chain ID
     */
    function _processNonceInvalidation(address owner, NoncesToInvalidate memory invalidations) internal {
        uint256 length = invalidations.salts.length;

        for (uint256 i = 0; i < length; i++) {
            usedNonces[owner][invalidations.salts[i]] = 1;
        }
    }

    /**
     * @notice Consume a nonce, marking it as used
     * @dev Reverts if nonce is already used
     * @param owner Token owner using the nonce
     * @param salt Salt value to consume
     */
    function _useNonce(address owner, bytes32 salt) internal {
        require(usedNonces[owner][salt] == 0, NonceAlreadyUsed());
        usedNonces[owner][salt] = 1;
    }
}
