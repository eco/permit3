// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { IPermit3 } from "./interfaces/IPermit3.sol";
import { IUnhingedMerkleTree } from "./interfaces/IUnhingedMerkleTree.sol";
import { UnhingedMerkleTree } from "./lib/UnhingedMerkleTree.sol";

import { NonceManager } from "./NonceManager.sol";
import { PermitBase } from "./PermitBase.sol";

/**
 * @title Permit3
 * @notice A cross-chain token approval and transfer system using EIP-712 signatures with UnhingedProofs
 * @dev Key features and components:
 * 1. Cross-chain Compatibility: Single signature can authorize operations across multiple chains
 * 2. Batched Operations: Process multiple token approvals and transfers in one transaction
 * 3. Flexible Nonce System: Non-sequential nonces for concurrent operations and gas optimization
 * 4. Time-bound Approvals: Permissions can be set to expire automatically
 * 5. EIP-712 Typed Signatures: Enhanced security through structured data signing
 * 6. UnhingedProofs: Optimized proof structure for cross-chain verification
 */
contract Permit3 is IPermit3, PermitBase, NonceManager {
    using ECDSA for bytes32;
    using UnhingedMerkleTree for bytes32;
    using UnhingedMerkleTree for IUnhingedMerkleTree.UnhingedProof;

    /**
     * @dev EIP-712 typehash for bundled chain permits
     * Includes nested SpendTransferPermit struct for structured token permissions
     * Used in cross-chain signature verification
     */
    bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
        "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 transferOrExpiration,address token,address spender,uint160 amountDelta)"
    );

    /**
     * @dev EIP-712 typehash for the primary permit signature
     * Binds owner, deadline, and permit data hash for signature verification
     */
    bytes32 public constant SIGNED_PERMIT3_TYPEHASH =
        keccak256("SignedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)");

    /**
     * @dev EIP-712 typehash for the unhinged merkle tree permit signature
     * Used for enhanced cross-chain operations
     */
    bytes32 public constant SIGNED_UNHINGED_PERMIT3_TYPEHASH = keccak256(
        "SignedUnhingedPermit3(address owner,bytes32 salt,uint256 deadline,uint48 timestamp,bytes32 unhingedRoot)"
    );

    // Constants for witness type hash strings
    string private constant _PERMIT_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(ChainPermits permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,";

    string private constant _PERMIT_BATCH_WITNESS_TYPEHASH_STUB =
        "PermitBatchWitnessTransferFrom(ChainPermits[] permitted,address spender,bytes32 salt,uint256 deadline,uint48 timestamp,";

    string private constant _PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB =
        "PermitUnhingedWitnessTransferFrom(bytes32 unhingedRoot,address owner,bytes32 salt,uint256 deadline,uint48 timestamp,";

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

    // Helper struct to avoid stack-too-deep errors
    struct PermitParams {
        address owner;
        bytes32 salt;
        uint256 deadline;
        uint48 timestamp;
        bytes32 currentChainHash;
        bytes32 unhingedRoot;
    }

    /**
     * @notice Process token approvals across multiple chains using Unhinged Merkle Tree
     * @param owner Token owner authorizing the operations
     * @param salt Unique salt for replay protection
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param proof Cross-chain proof data using Unhinged Merkle Tree
     * @param signature EIP-712 signature covering the entire cross-chain batch
     */
    function permit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        UnhingedPermitProof memory proof,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(proof.permits.chainId == block.chainid, WrongChainId(block.chainid, proof.permits.chainId));

        // Use a struct to avoid stack-too-deep errors
        PermitParams memory params;
        params.owner = owner;
        params.salt = salt;
        params.deadline = deadline;
        params.timestamp = timestamp;

        // Hash current chain's permits
        params.currentChainHash = _hashChainPermits(proof.permits);

        // Calculate the unhinged root from the proof components
        // First verify the proof structure is valid (boolean return value function)
        if (!proof.unhingedProof.verifyProofStructure()) {
            revert IUnhingedMerkleTree.InvalidUnhingedProof();
        }

        // If verification succeeds, calculate the root (reverts on errors)
        params.unhingedRoot = proof.unhingedProof.calculateRoot(params.currentChainHash);

        // Verify signature with unhinged root
        bytes32 signedHash = keccak256(
            abi.encode(
                SIGNED_UNHINGED_PERMIT3_TYPEHASH,
                params.owner,
                params.salt,
                params.deadline,
                params.timestamp,
                params.unhingedRoot
            )
        );

        _verifySignature(params.owner, signedHash, signature);
        _processChainPermits(params.owner, params.salt, params.timestamp, proof.permits);
    }

    /**
     * @dev Core permit processing logic
     * @param owner Token owner
     * @param chain Bundle of permit operations to process
     * @notice Handles two types of operations:
     * 1. Immediate transfers (transferOrExpiration = 1)
     * 2. Allowance updates (transferOrExpiration = future timestamp)
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
                // If the allowance is locked, only allow unlock operation with newer timestamp
                if (allowed.expiration == LOCKED_ALLOWANCE) {
                    // Special handling for unlock operation
                    if (p.modeOrExpiration == uint48(PermitType.Unlock)) {
                        // Only allow unlock if timestamp is newer than lock timestamp
                        if (timestamp <= allowed.timestamp) {
                            revert AllowanceLocked();
                        }
                    } else {
                        // For all other operations, reject if allowance is locked
                        revert AllowanceLocked();
                    }
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
     * @notice Process token approvals with witness data for single chain operations
     * @dev Handles permitWitnessTransferFrom operations with dynamic witness data
     * @param owner The token owner authorizing the permits
     * @param salt Unique salt for replay protection
     * @param deadline Timestamp limiting signature validity for security
     * @param timestamp Timestamp of the permit
     * @param chain Structured data containing token approval parameters
     * @param witness Additional data to include in signature verification
     * @param witnessTypeString EIP-712 type definition for witness data
     * @param signature EIP-712 signature authorizing all permits with witness
     */
    function permitWitnessTransferFrom(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        ChainPermits memory chain,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(chain.chainId == block.chainid, WrongChainId(block.chainid, chain.chainId));

        // Validate witness type string format
        _validateWitnessTypeString(witnessTypeString);

        // Get hash of permits data
        bytes32 permitDataHash = _hashChainPermits(chain);

        // Compute witness-specific typehash and signed hash
        bytes32 typeHash = _getWitnessTypeHash(witnessTypeString);
        bytes32 signedHash = keccak256(abi.encode(typeHash, permitDataHash, owner, salt, deadline, timestamp, witness));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, salt, timestamp, chain);
    }

    // Helper struct to avoid stack-too-deep errors
    struct WitnessParams {
        address owner;
        bytes32 salt;
        uint256 deadline;
        uint48 timestamp;
        bytes32 witness;
        bytes32 currentChainHash;
        bytes32 unhingedRoot;
    }

    /**
     * @notice Process permit with additional witness data for cross-chain operations
     * @param owner Token owner address
     * @param salt Unique salt for replay protection
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param proof Cross-chain proof data using Unhinged Merkle Tree
     * @param witness Additional data to include in signature verification
     * @param witnessTypeString EIP-712 type definition for witness data
     * @param signature EIP-712 signature authorizing the batch
     */
    function permitWitnessTransferFrom(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        UnhingedPermitProof memory proof,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, SignatureExpired());
        require(proof.permits.chainId == block.chainid, WrongChainId(block.chainid, proof.permits.chainId));

        // Validate witness type string format
        _validateWitnessTypeString(witnessTypeString);

        // Use a struct to avoid stack-too-deep errors
        WitnessParams memory params;
        params.owner = owner;
        params.salt = salt;
        params.deadline = deadline;
        params.timestamp = timestamp;
        params.witness = witness;

        // Hash current chain's permits
        params.currentChainHash = _hashChainPermits(proof.permits);

        // Calculate the unhinged root
        // First verify the proof structure is valid (boolean return value function)
        if (!proof.unhingedProof.verifyProofStructure()) {
            revert IUnhingedMerkleTree.InvalidUnhingedProof();
        }

        // If verification succeeds, calculate the root (reverts on errors)
        params.unhingedRoot = proof.unhingedProof.calculateRoot(params.currentChainHash);

        // Compute witness-specific typehash and signed hash
        bytes32 typeHash = _getUnhingedWitnessTypeHash(witnessTypeString);
        bytes32 signedHash = keccak256(
            abi.encode(
                typeHash,
                params.unhingedRoot,
                params.owner,
                params.salt,
                params.deadline,
                params.timestamp,
                params.witness
            )
        );

        _verifySignature(params.owner, signedHash, signature);
        _processChainPermits(params.owner, params.salt, params.timestamp, proof.permits);
    }

    /**
     * @dev Validates that a witness type string is properly formatted
     * @param witnessTypeString The EIP-712 type string to validate
     */
    function _validateWitnessTypeString(
        string calldata witnessTypeString
    ) internal pure {
        // Validate minimum length
        require(bytes(witnessTypeString).length > 0, InvalidWitnessTypeString());

        // Validate proper ending with closing parenthesis
        require(bytes(witnessTypeString)[bytes(witnessTypeString).length - 1] == ")", InvalidWitnessTypeString());
    }

    /**
     * @dev Constructs a complete witness type hash from type string and stub
     * @param witnessTypeString The EIP-712 witness type string
     * @return bytes32 The complete type hash
     */
    function _getWitnessTypeHash(
        string calldata witnessTypeString
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_PERMIT_WITNESS_TYPEHASH_STUB, witnessTypeString));
    }

    /**
     * @dev Constructs a complete unhinged witness type hash from type string and stub
     * @param witnessTypeString The EIP-712 witness type string
     * @return bytes32 The complete type hash for unhinged operations
     */
    function _getUnhingedWitnessTypeHash(
        string memory witnessTypeString
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB, witnessTypeString));
    }

    /**
     * @notice Returns the witness typehash stub for EIP-712 signature verification
     * @return The stub string for witness permit typehash
     */
    function PERMIT_WITNESS_TYPEHASH_STUB() external pure returns (string memory) {
        return _PERMIT_WITNESS_TYPEHASH_STUB;
    }

    /**
     * @notice Returns the batch witness typehash stub for EIP-712 signature verification
     * @return The stub string for batch witness permit typehash
     */
    function PERMIT_BATCH_WITNESS_TYPEHASH_STUB() external pure returns (string memory) {
        return _PERMIT_BATCH_WITNESS_TYPEHASH_STUB;
    }

    /**
     * @notice Returns the unhinged witness typehash stub for EIP-712 signature verification
     * @return The stub string for unhinged witness permit typehash
     */
    function PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB() external pure returns (string memory) {
        return _PERMIT_UNHINGED_WITNESS_TYPEHASH_STUB;
    }

    /**
     * @dev Validate EIP-712 signature against expected signer
     * @param owner Expected message signer
     * @param structHash Hash of the signed data structure
     * @param signature Raw signature bytes (v, r, s)
     */
    function _verifySignature(address owner, bytes32 structHash, bytes calldata signature) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(signature);
        require(signer == owner, InvalidSignature());
    }
}
