// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { INonceManager } from "./interfaces/INonceManager.sol";
import { EIP712 } from "./lib/EIP712.sol";

import { TreeNodeLib } from "./lib/TreeNodeLib.sol";

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
    using SignatureChecker for address;

    /// @dev Constant representing an unused nonce
    bool private constant NONCE_NOT_USED = false;

    /// @dev Constant representing a used nonce
    bool private constant NONCE_USED = true;

    /**
     * @notice Maps owner address to their used nonces
     * @dev Non-sequential nonces allow parallel operations without conflicts
     */
    mapping(address => mapping(bytes32 => bool)) internal usedNonces;

    /**
     * @notice EIP-712 typehash for single-chain signed nonce invalidation
     * @dev Includes owner, deadline, and NoncesToInvalidate struct for single-chain invalidation
     * @dev Parallel to PERMIT3_TYPEHASH pattern
     */
    bytes32 public constant INVALIDATE_NONCES_TYPEHASH = keccak256(
        "InvalidateNonces(address owner,uint48 deadline,NoncesToInvalidate noncesToInvalidate)NoncesToInvalidate(uint64 chainId,bytes32[] salts)"
    );

    /**
     * @notice EIP-712 typehash for tree-based multi-chain nonce invalidation
     * @dev Includes owner, deadline, and NonceNode tree for UI transparency and cross-chain invalidation
     * @dev Binary tree structure where leaves are NoncesToInvalidate (chain-specific nonce lists)
     * @dev Parallel to MULTICHAIN_PERMIT3_TYPEHASH pattern
     */
    bytes32 public constant MULTICHAIN_INVALIDATE_NONCES_TYPEHASH = keccak256(
        "InvalidateNonces(address owner,uint48 deadline,NonceNode nonceTree)NonceNode(NonceNode[] nodes,NoncesToInvalidate[] nonces)NoncesToInvalidate(uint64 chainId,bytes32[] salts)"
    );

    /**
     * @notice EIP-712 typehash for NonceNode structure
     * @dev Used for hashing NonceNode in tree reconstruction with MULTICHAIN_INVALIDATE_NONCES_TYPEHASH
     * @dev Binary tree where leaves are NoncesToInvalidate structs, not raw bytes32 nonces
     */
    bytes32 internal constant NONCE_NODE_TYPEHASH = keccak256(
        "NonceNode(NonceNode[] nodes,NoncesToInvalidate[] nonces)NoncesToInvalidate(uint64 chainId,bytes32[] salts)"
    );

    /**
     * @notice EIP-712 typehash for nonce invalidation
     * @dev Includes chainId for cross-chain replay protection
     */
    bytes32 public constant NONCES_TO_INVALIDATE_TYPEHASH =
        keccak256("NoncesToInvalidate(uint64 chainId,bytes32[] salts)");

    /**
     * @notice Initialize EIP-712 domain separator
     * @param name Contract name for EIP-712 domain
     * @param version Contract version for EIP-712 domain
     */
    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) { }

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
    function isNonceUsed(
        address owner,
        bytes32 salt
    ) external view returns (bool) {
        return usedNonces[owner][salt];
    }

    /**
     * @notice Directly invalidate multiple nonces without signature
     * @param salts Array of salts to mark as used
     */
    function invalidateNonces(
        bytes32[] calldata salts
    ) external {
        _processNonceInvalidation(msg.sender, salts);
    }

    /**
     * @notice Invalidate nonces using a signed message
     * @param salts Array of nonce salts to invalidate
     * @param sig Signature data (owner, deadline, signature)
     */
    function invalidateNonces(
        bytes32[] calldata salts,
        NonceSignature calldata sig
    ) external {
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }

        NoncesToInvalidate memory invalidations = NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });

        // Hash the NoncesToInvalidate struct according to EIP-712
        bytes32 invalidationsHash = keccak256(
            abi.encode(
                NONCES_TO_INVALIDATE_TYPEHASH, invalidations.chainId, keccak256(abi.encodePacked(invalidations.salts))
            )
        );

        bytes32 signedHash =
            keccak256(abi.encode(INVALIDATE_NONCES_TYPEHASH, sig.owner, sig.deadline, invalidationsHash));

        _verifySignature(sig.owner, signedHash, sig.signature);

        _processNonceInvalidation(sig.owner, salts);
    }

    /**
     * @notice Invalidate multiple nonces using tree structure with UI transparency
     * @dev User signs complete NonceNode showing all nonces being invalidated
     * @dev Reconstructs NonceNode hash from compact encoding for signature verification
     * @param tree NonceTree containing proofStructure, currentChainInvalidations, and proof
     * @param sig Signature data (owner, deadline, signature)
     */
    function invalidateNonces(
        NonceTree calldata tree,
        NonceSignature calldata sig
    ) external {
        // Validate deadline
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }

        // Validate chain ID matches current chain
        if (tree.currentChainInvalidations.chainId != uint64(block.chainid)) {
            revert WrongChainId(uint64(block.chainid), tree.currentChainInvalidations.chainId);
        }

        // Hash the current chain's NoncesToInvalidate as a leaf
        bytes32 currentChainHash = hashNoncesToInvalidate(tree.currentChainInvalidations);

        // Reconstruct the NonceNode hash from the proof and tree structure
        bytes32 nonceNodeHash =
            TreeNodeLib.computeTreeHash(NONCE_NODE_TYPEHASH, tree.proofStructure, tree.proof, currentChainHash);

        // Verify signature with MULTICHAIN_INVALIDATE_NONCES_TYPEHASH
        bytes32 signedHash =
            keccak256(abi.encode(MULTICHAIN_INVALIDATE_NONCES_TYPEHASH, sig.owner, sig.deadline, nonceNodeHash));

        _verifySignature(sig.owner, signedHash, sig.signature);

        // Process nonce cancellation
        _processNonceInvalidation(sig.owner, tree.currentChainInvalidations.salts);
    }

    /**
     * @notice Generate EIP-712 hash for NoncesToInvalidate struct
     * @dev Hashes the struct for use as a leaf in tree reconstruction
     * @dev Uses single-nonce optimization for gas efficiency
     * @dev Preserves salt order - no sorting (order matters for hash)
     * @param invalidations Struct containing chain ID and nonces to invalidate
     * @return bytes32 Hash suitable for tree leaf
     */
    function hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) public pure returns (bytes32) {
        if (invalidations.salts.length == 0) {
            return bytes32(0);
        }

        // Single nonce optimization - use the nonce directly as hash
        if (invalidations.salts.length == 1) {
            return invalidations.salts[0];
        }

        // Multiple nonces - hash as EIP-712 NoncesToInvalidate struct
        return keccak256(
            abi.encode(
                NONCES_TO_INVALIDATE_TYPEHASH, invalidations.chainId, keccak256(abi.encodePacked(invalidations.salts))
            )
        );
    }

    /**
     * @dev Process batch nonce invalidation by marking all specified nonces as used
     * @param owner Token owner whose nonces are being invalidated
     * @param salts Array of salts to invalidate
     * @notice This function iterates through all provided salts and:
     *         1. Marks each nonce as NONCE_USED in the usedNonces mapping
     *         2. Emits a NonceInvalidated event for each invalidated nonce
     * @notice This is an internal helper used by the public invalidateNonces functions
     *         to process the actual invalidation after signature verification
     */
    function _processNonceInvalidation(
        address owner,
        bytes32[] memory salts
    ) internal {
        uint256 saltsLength = salts.length;

        require(saltsLength != 0, EmptyArray());

        for (uint256 i = 0; i < saltsLength; i++) {
            usedNonces[owner][salts[i]] = NONCE_USED;
            emit NonceInvalidated(owner, salts[i]);
        }
    }

    /**
     * @dev Consume a nonce by marking it as used for replay protection
     * @param owner Token owner whose nonce is being consumed
     * @param salt Unique salt value identifying the nonce to consume
     * @notice This function provides replay protection by:
     *         1. Checking if the nonce has already been used (NONCE_NOT_USED = 0)
     *         2. Marking the nonce as used (NONCE_USED = 1)
     * @notice Reverts with NonceAlreadyUsed() if the nonce was previously consumed
     * @notice This is called before processing permits to ensure each signature
     *         can only be used once per salt value
     */
    function _useNonce(
        address owner,
        bytes32 salt
    ) internal {
        if (usedNonces[owner][salt]) {
            revert NonceAlreadyUsed(owner, salt);
        }
        usedNonces[owner][salt] = NONCE_USED;
    }

    /**
     * @dev Validate EIP-712 signature against expected signer using ECDSA recovery
     * @param owner Expected message signer to validate against
     * @param structHash Hash of the signed data structure (pre-hashed message)
     * @param signature Raw signature bytes in (v, r, s) format for ECDSA recovery
     * @notice This function:
     *         1. Computes the EIP-712 compliant digest using _hashTypedDataV4
     *         2. For short signatures (<=65 bytes), tries ECDSA recovery first
     *         3. Falls back to ERC-1271 validation for contract wallets or if ECDSA fails
     *         4. Handles EIP-7702 delegated EOAs correctly
     * @notice Reverts with InvalidSignature() if the signature is invalid or
     *         the recovered signer doesn't match the expected owner
     */
    function _verifySignature(
        address owner,
        bytes32 structHash,
        bytes calldata signature
    ) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);

        // For signatures == 65 bytes ECDSA first then falling back to ERC-1271
        // We don't check for code length as EIP-7702 EOAs can have code
        if (signature.length == 65) {
            (address signer,,) = digest.tryRecover(signature);
            if (signer != address(0) && signer == owner) {
                return;
            }
        }

        // For longer signatures or when ECDSA failed use ERC-1271 validation
        if (owner.code.length == 0 || !owner.isValidERC1271SignatureNow(digest, signature)) {
            revert InvalidSignature(owner);
        }
    }
}
