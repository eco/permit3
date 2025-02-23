// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit3 } from "./interfaces/IPermit3.sol";
import { EIP712 } from "./lib/EIP712.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Permit3
 * @notice A cross-chain token approval and transfer system using EIP-712 signatures
 * @dev Key features and components:
 * 1. Cross-chain Compatibility: Single signature can authorize operations across multiple chains
 * 2. Batched Operations: Process multiple token approvals and transfers in one transaction
 * 3. Flexible Nonce System: Non-sequential nonces for concurrent operations and gas optimization
 * 4. Time-bound Approvals: Permissions can be set to expire automatically
 * 5. EIP-712 Typed Signatures: Enhanced security through structured data signing
 */
contract Permit3 is IPermit3, EIP712 {
    using ECDSA for bytes32;

    /// @dev Core data structure for tracking token permissions
    /// Maps: owner => token => spender => {amount, expiration, nonce}
    mapping(address => mapping(address => mapping(address => Allowance))) public allowances;

    /// @dev Nonce tracking system for replay protection
    /// Maps: owner => nonce => status (0 = unused, 1 = used)
    /// Non-sequential nonces allow parallel operations without nonce conflicts
    mapping(address => mapping(uint48 => uint256)) public usedNonces;

    /// @dev EIP-712 typehash for bundled chain permits
    /// Includes nested SpendTransferPermit struct for structured token permissions
    /// Used in cross-chain signature verification
    bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
        "ChainPermits(uint64 chainId,uint48 nonce,SpendTransferPermit[] permits)SpendTransferPermit(uint48 transferOrExpiration,address token,address spender,uint160 amount)"
    );

    /// @dev EIP-712 typehash for the primary permit signature
    /// Binds owner, deadline, and permit data hash for signature verification
    bytes32 public constant SIGNED_PERMIT3_TYPEHASH =
        keccak256("SignedPermit3(address owner,uint256 deadline,bytes32 chainedPermitsHashes)");

    /// @dev EIP-712 typehash for nonce invalidation requests
    /// Used when canceling pending or unused nonces
    bytes32 public constant NONCES_TO_INVALIDATE_TYPEHASH =
        keccak256("NoncesToInvalidate(uint64 chainId,uint48[] noncesToInvalidate)");

    /// @dev EIP-712 typehash for cancellation signatures
    /// Similar to SIGNED_PERMIT3_TYPEHASH but for cancellation operations
    bytes32 public constant SIGNED_CANCEL_PERMIT3_TYPEHASH =
        keccak256("SignedCancelPermit3(address owner,uint256 deadline,bytes32 chainedInvalidationHashes)");

    /**
     * @dev Sets up EIP-712 domain separator with protocol identifiers
     * @notice Establishes the contract's domain for typed data signing
     */
    constructor() EIP712("Permit3", "1") { }

    /**
     * @notice Process token approvals for a single chain
     * @dev Core permit processing function for single-chain operations
     * @param owner The token owner authorizing the permits
     * @param deadline Timestamp limiting signature validity for security
     * @param permits Structured data containing token approval parameters
     * @param signature EIP-712 signature authorizing all permits in the batch
     */
    function permit(address owner, uint256 deadline, ChainPermits memory permits, bytes calldata signature) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 signedHash = keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, deadline, _hashChainPermits(permits)));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, permits);
    }

    /**
     * @notice Process token approvals across multiple chains
     * @dev Handles complex cross-chain permit batches using hash chaining
     * @param owner Token owner authorizing the operations
     * @param deadline Signature expiration timestamp
     * @param batch Contains:
     *        - preHash: Combined hash of permits from previous chains
     *        - permits: Current chain's permit data
     *        - followingHashes: Hashes of permits for subsequent chains
     * @param signature EIP-712 signature covering the entire cross-chain batch
     */
    function permit(address owner, uint256 deadline, Permit3Proof memory batch, bytes calldata signature) external {
        require(block.timestamp <= deadline, "Permit expired");

        // Chain all permit hashes together to verify the complete cross-chain operation
        bytes32 chainedPermitsHashes = batch.preHash;
        chainedPermitsHashes = keccak256(abi.encodePacked(chainedPermitsHashes, _hashChainPermits(batch.permits)));

        for (uint256 i = 0; i < batch.followingHashes.length; i++) {
            chainedPermitsHashes = keccak256(abi.encodePacked(chainedPermitsHashes, batch.followingHashes[i]));
        }

        bytes32 signedHash =
            keccak256(abi.encode(SIGNED_CANCEL_PERMIT3_TYPEHASH, owner, deadline, chainedPermitsHashes));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, batch.permits);
    }

    /**
     * @dev Core permit processing logic
     * @param owner Token owner
     * @param permits Bundle of permit operations to process
     * @notice Handles two types of operations:
     * 1. Immediate transfers (transferOrExpiration = 1)
     * 2. Allowance updates (transferOrExpiration = future timestamp)
     */
    function _processChainPermits(address owner, ChainPermits memory permits) internal {
        require(usedNonces[owner][permits.nonce] == 0, "Nonce already used");
        usedNonces[owner][permits.nonce] = 1;

        for (uint256 i = 0; i < permits.permits.length; i++) {
            SpendTransferPermit memory p = permits.permits[i];

            if (p.transferOrExpiration == 1) {
                // Immediate transfer mode
                _transferFrom(owner, p.spender, p.amount, p.token);
            } else {
                // Update allowance with expiration
                allowances[owner][p.token][p.spender] =
                    Allowance({ amount: p.amount, expiration: p.transferOrExpiration, nonce: permits.nonce });

                emit Permit(owner, p.token, p.spender, p.amount, p.transferOrExpiration, permits.nonce);
            }
        }
    }

    /**
     * @dev Execute token transfer with safety checks
     * @param from Token sender
     * @param to Token recipient
     * @param amount Transfer amount
     * @param token ERC20 token contract
     */
    function _transferFrom(address from, address to, uint160 amount, address token) internal {
        require(IERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    /**
     * @dev Generate EIP-712 compatible hash for chain permits
     * @param permits Chain-specific permit data
     * @return bytes32 Combined hash of all permit parameters
     */
    function _hashChainPermits(
        ChainPermits memory permits
    ) internal pure returns (bytes32) {
        bytes32[] memory permitHashes = new bytes32[](permits.permits.length);
        for (uint256 i = 0; i < permits.permits.length; i++) {
            permitHashes[i] = keccak256(
                abi.encode(
                    permits.permits[i].transferOrExpiration,
                    permits.permits[i].token,
                    permits.permits[i].spender,
                    permits.permits[i].amount
                )
            );
        }

        return keccak256(
            abi.encode(
                CHAIN_PERMITS_TYPEHASH, permits.chainId, permits.nonce, keccak256(abi.encodePacked(permitHashes))
            )
        );
    }

    /**
     * @dev Validate EIP-712 signature against expected signer
     * @param owner Expected message signer
     * @param structHash Hash of the signed data structure
     * @param signature Raw signature bytes (v, r, s)
     */
    function _verifySignature(address owner, bytes32 structHash, bytes calldata signature) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);
        require(digest.recover(signature) == owner, "Invalid signature");
    }

    /**
     * @notice Query current token allowance
     * @dev Retrieves full allowance details including expiration
     * @param user Token owner
     * @param token ERC20 token address
     * @param spender Approved spender
     * @return amount Current approved amount
     * @return expiration Timestamp when approval expires (0 = no expiration)
     * @return nonce Nonce used for this approval
     */
    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 nonce) {
        Allowance memory allowed = allowances[user][token][spender];
        return (allowed.amount, allowed.expiration, allowed.nonce);
    }

    /**
     * @notice Direct allowance approval without signature
     * @dev Alternative to permit() for simple approvals
     * @param token ERC20 token address
     * @param spender Address to approve
     * @param amount Approval amount
     * @param expiration Optional expiration timestamp
     */
    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        allowances[msg.sender][token][spender] = Allowance({ amount: amount, expiration: expiration, nonce: 0 });

        emit Approval(msg.sender, token, spender, amount, expiration);
    }

    /**
     * @notice Execute approved token transfer
     * @dev Checks allowance and expiration before transfer
     * @param from Token owner
     * @param to Transfer recipient
     * @param amount Transfer amount
     * @param token ERC20 token address
     */
    function transferFrom(address from, address to, uint160 amount, address token) external {
        Allowance storage allowed = allowances[from][token][msg.sender];
        require(block.timestamp <= allowed.expiration || allowed.expiration == 0, "Allowance expired");

        if (allowed.amount != type(uint160).max) {
            require(allowed.amount >= amount, "Insufficient allowance");
            allowed.amount -= amount;
        }

        require(IERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    /**
     * @notice Execute multiple approved transfers
     * @dev Batch version of transferFrom()
     * @param transfers Array of transfer instructions
     */
    function transferFrom(
        AllowanceTransferDetails[] calldata transfers
    ) external {
        for (uint256 i = 0; i < transfers.length; i++) {
            _transferFrom(transfers[i].from, transfers[i].to, transfers[i].amount, transfers[i].token);
        }
    }

    /**
     * @notice Revoke multiple token approvals
     * @dev Emergency function to quickly remove permissions
     * @param approvals Array of token-spender pairs to revoke
     */
    function lockdown(
        TokenSpenderPair[] calldata approvals
    ) external {
        for (uint256 i = 0; i < approvals.length; i++) {
            address token = approvals[i].token;
            address spender = approvals[i].spender;

            delete allowances[msg.sender][token][spender];
            emit Lockdown(msg.sender, token, spender);
        }
    }

    /**
     * @notice Directly invalidate nonces
     * @dev Prevents future use of specified nonces
     * @param noncesToInvalidate Array of nonces to mark as used
     */
    function invalidateNonces(
        uint48[] calldata noncesToInvalidate
    ) external {
        for (uint256 i = 0; i < noncesToInvalidate.length; i++) {
            usedNonces[msg.sender][noncesToInvalidate[i]] = 1;
        }
    }

    /**
     * @notice Invalidate nonces with signature authorization
     * @dev Allows owners to invalidate nonces through signed messages
     * @param owner Token owner
     * @param deadline Signature expiration
     * @param invalidations Nonces to invalidate
     * @param signature Authorization signature
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        NoncesToInvalidate memory invalidations,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");

        bytes32 signedHash = keccak256(
            abi.encode(SIGNED_CANCEL_PERMIT3_TYPEHASH, owner, deadline, _hashNoncesToInvalidate(invalidations))
        );

        _verifySignature(owner, signedHash, signature);
        _processNonceInvalidation(owner, invalidations);
    }

    /**
     * @notice Cross-chain nonce invalidation
     * @dev Similar to cross-chain permits but for nonce invalidation
     * @param owner Token owner
     * @param deadline Signature expiration
     * @param proof Cross-chain invalidation proof
     * @param signature Authorization signature
     */
    function invalidateNonces(
        address owner,
        uint256 deadline,
        CancelPermit3Proof memory proof,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");

        bytes32 chainedInvalidationHashes = proof.preHash;
        chainedInvalidationHashes =
            keccak256(abi.encodePacked(chainedInvalidationHashes, _hashNoncesToInvalidate(proof.invalidations)));

        for (uint256 i = 0; i < proof.followingHashes.length; i++) {
            chainedInvalidationHashes = keccak256(abi.encodePacked(chainedInvalidationHashes, proof.followingHashes[i]));
        }

        bytes32 signedHash = keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, deadline, chainedInvalidationHashes));

        _verifySignature(owner, signedHash, signature);
        _processNonceInvalidation(owner, proof.invalidations);
    }

    /**
     * @dev Generate hash for nonce invalidation data
     * @param invalidations Nonce invalidation parameters
     * @return bytes32 EIP-712 compatible hash
     */
    function _hashNoncesToInvalidate(
        NoncesToInvalidate memory invalidations
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(NONCES_TO_INVALIDATE_TYPEHASH, invalidations.chainId, invalidations.noncesToInvalidate)
        );
    }

    /**
     * @dev Mark nonces as used
     * @param owner Token owner
     * @param invalidations Nonce invalidation parameters
     */
    function _processNonceInvalidation(address owner, NoncesToInvalidate memory invalidations) internal {
        for (uint256 i = 0; i < invalidations.noncesToInvalidate.length; i++) {
            usedNonces[owner][invalidations.noncesToInvalidate[i]] = 1;
        }
    }
}
