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
        "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,address token,address account,uint160 amountDelta)"
    );

    /**
     * @dev EIP-712 typehash for the primary permit signature
     * Binds owner, deadline, and permit data hash for signature verification
     */
    bytes32 public constant SIGNED_PERMIT3_TYPEHASH = keccak256(
        "SignedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unbalancedPermitsRoot)"
    );
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
     * @param timestamp Timestamp of the permit
     * @param chain Structured data containing token approval parameters
     * @param signature EIP-712 signature authorizing all permits in the batch
     */
    function permit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        ChainPermits memory chain,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(chain.chainId == block.chainid, WrongChainId(block.chainid, chain.chainId));

        bytes32 signedHash =
            keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, salt, deadline, timestamp, _hashChainPermits(chain)));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, salt, timestamp, chain);
    }

    /**
     * @notice Process token approvals across multiple chains
     * @dev Handles complex cross-chain permit batches using hash chaining
     * @param owner Token owner authorizing the operations
     * @param salt Asynchronous identifier to prevent replay attacks across different permit batches
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param proof Contains:
     *        - preHash: Combined hash of permits from previous chains
     *        - permits: Current chain's permit data
     *        - followingHashes: Hashes of permits for subsequent chains
     * @param signature EIP-712 signature covering the entire cross-chain batch
     */
    function permit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        Permit3Proof memory proof,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(proof.permits.chainId == block.chainid, WrongChainId(block.chainid, proof.permits.chainId));

        // Chain all permit hashes together to verify the complete cross-chain operation
        bytes32 unbalancedPermitsRoot = proof.preHash;
        unbalancedPermitsRoot = keccak256(abi.encodePacked(unbalancedPermitsRoot, _hashChainPermits(proof.permits)));

        for (uint256 i = 0; i < proof.followingHashes.length; i++) {
            unbalancedPermitsRoot = keccak256(abi.encodePacked(unbalancedPermitsRoot, proof.followingHashes[i]));
        }

        bytes32 signedHash =
            keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, salt, deadline, timestamp, unbalancedPermitsRoot));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, salt, timestamp, proof.permits);
    }

    /**
     * @dev Core permit processing logic
     * @param owner Token owner
     * @param chain Bundle of permit operations to process
     * @notice Handles multiple types of operations:
     * @param modeOrExpiration Mode indicators:
     *        = 0: Immediate transfer mode
     *        = 1: Decrease allowance mode
     *        = 2: Lock allowance mode
     *        = 3: Unlock allowance mode
     *        > 3: Increase allowance mode, new expiration for the allowance if the timestamp is recent
     */
    function _processChainPermits(address owner, bytes32 salt, uint48 timestamp, ChainPermits memory chain) internal {
        _useNonce(owner, salt);

        for (uint256 i = 0; i < chain.permits.length; i++) {
            AllowanceOrTransfer memory p = chain.permits[i];

            if (p.modeOrExpiration == uint48(PermitType.Transfer)) {
                _transferFrom(owner, p.account, p.amountDelta, p.token);
            } else {
                Allowance memory allowed = allowances[owner][p.token][p.account];

                // Check if allowance is locked
                // TODO: decide if locks can be extended in a single call
                // currently not allowed in a single operation but allowed via an unlock / lock multicall
                if (
                    allowed.expiration == LOCKED_ALLOWANCE
                        && (p.modeOrExpiration != uint48(PermitType.Unlock) || timestamp <= allowed.timestamp)
                ) {
                    revert AllowanceLocked();
                }

                if (p.modeOrExpiration == uint48(PermitType.Decrease)) {
                    // Decrease allowance
                    if (allowed.amount != MAX_ALLOWANCE || p.amountDelta == MAX_ALLOWANCE) {
                        allowed.amount = p.amountDelta > allowed.amount ? 0 : allowed.amount - p.amountDelta;
                    }
                } else if (p.modeOrExpiration == uint48(PermitType.Lock)) {
                    // Lockdown allowance
                    allowed.amount = 0;
                    allowed.expiration = LOCKED_ALLOWANCE;
                    allowed.timestamp = timestamp;
                } else if (p.modeOrExpiration == uint48(PermitType.Unlock)) {
                    // Unlock allowance
                    allowed.amount = p.amountDelta;
                    allowed.expiration = 0;
                    allowed.timestamp = timestamp;
                } else {
                    if (p.amountDelta > 0) {
                        // Increase allowance
                        if (allowed.amount != MAX_ALLOWANCE) {
                            if (p.amountDelta == MAX_ALLOWANCE) {
                                allowed.amount = MAX_ALLOWANCE;
                            } else {
                                allowed.amount += p.amountDelta;
                            }
                        }
                    }

                    if (timestamp > allowed.timestamp) {
                        allowed.expiration = p.modeOrExpiration;
                        allowed.timestamp = timestamp;
                    }
                }

                emit Permit(owner, p.token, p.account, allowed.amount, allowed.expiration, timestamp);

                allowances[owner][p.token][p.account] = allowed;
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
                    permits.permits[i].modeOrExpiration,
                    permits.permits[i].token,
                    permits.permits[i].account,
                    permits.permits[i].amountDelta
                )
            );
        }

        return keccak256(abi.encode(CHAIN_PERMITS_TYPEHASH, permits.chainId, keccak256(abi.encodePacked(permitHashes))));
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
