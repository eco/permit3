// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { IPermit3 } from "./interfaces/IPermit3.sol";

import { NonceManager } from "./NonceManager.sol";
import { PermitBase } from "./PermitBase.sol";

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
contract Permit3 is IPermit3, PermitBase, NonceManager {
    using ECDSA for bytes32;

    /**
     * @dev EIP-712 typehash for bundled chain permits
     * Includes nested SpendTransferPermit struct for structured token permissions
     * Used in cross-chain signature verification
     */
    bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
        "ChainPermits(uint64 chainId,uint48 nonce,SpendTransferPermit[] permits)SpendTransferPermit(uint48 transferOrExpiration,address token,address spender,uint160 amount)"
    );

    /**
     * @dev EIP-712 typehash for the primary permit signature
     * Binds owner, deadline, and permit data hash for signature verification
     */
    bytes32 public constant SIGNED_PERMIT3_TYPEHASH =
        keccak256("SignedPermit3(address owner,uint256 deadline,bytes32 chainedPermitsHashes)");

    /**
     * @dev Sets up EIP-712 domain separator with protocol identifiers
     * @notice Establishes the contract's domain for typed data signing
     */
    constructor() NonceManager("Permit3", "1") { }

    /**
     * @notice Process token approvals for a single chain
     * @dev Core permit processing function for single-chain operations
     * @param owner The token owner authorizing the permits
     * @param deadline Timestamp limiting signature validity for security
     * @param permits Structured data containing token approval parameters
     * @param signature EIP-712 signature authorizing all permits in the batch
     */
    function permit(address owner, uint256 deadline, ChainPermits memory permits, bytes calldata signature) external {
        require(block.timestamp <= deadline, SignatureExpired());

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
        require(block.timestamp <= deadline, SignatureExpired());

        // Chain all permit hashes together to verify the complete cross-chain operation
        bytes32 chainedPermitsHashes = batch.preHash;
        chainedPermitsHashes = keccak256(abi.encodePacked(chainedPermitsHashes, _hashChainPermits(batch.permits)));

        for (uint256 i = 0; i < batch.followingHashes.length; i++) {
            chainedPermitsHashes = keccak256(abi.encodePacked(chainedPermitsHashes, batch.followingHashes[i]));
        }

        bytes32 signedHash = keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, deadline, chainedPermitsHashes));

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
        _useNonce(owner, permits.nonce);

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
        require(digest.recover(signature) == owner, InvalidSignature());
    }
}
