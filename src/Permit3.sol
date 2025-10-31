// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit3 } from "./interfaces/IPermit3.sol";

import { TreeNodeLib } from "./lib/TreeNodeLib.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { MultiTokenPermit } from "./MultiTokenPermit.sol";
import { NonceManager } from "./NonceManager.sol";

/**
 * @title Permit3
 * @notice A cross-chain token approval and transfer system using EIP-712 signatures with merkle proofs
 * @dev Key features and components:
 * 1. Cross-chain Compatibility: Single signature can authorize operations across multiple chains
 * 2. Batched Operations: Process multiple token approvals and transfers in one transaction
 * 3. Flexible Nonce System: Non-sequential nonces for concurrent operations and gas optimization
 * 4. Time-bound Approvals: Permissions can be set to expire automatically
 * 5. EIP-712 Typed Signatures: Enhanced security through structured data signing
 * 6. Merkle Proofs: Optimized proof structure for cross-chain verification
 */
contract Permit3 is IPermit3, MultiTokenPermit, NonceManager {
    /**
     * @dev EIP-712 typehash for bundled chain permits
     * Includes nested SpendTransferPermit struct for structured token permissions
     * Used in cross-chain signature verification
     */
    bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
        "ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)"
    );

    /**
     * @dev EIP-712 typehash for single-chain permit signature
     * Binds owner, deadline, and chain permits for signature verification
     */
    bytes32 public constant PERMIT3_TYPEHASH = keccak256(
        "Permit3(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,ChainPermits chainPermits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)"
    );

    /**
     * @dev EIP-712 typehash for PermitNode structure signature
     * Binds owner, deadline, and permit node tree structure for UI transparency
     */
    bytes32 public constant MULTICHAIN_PERMIT3_TYPEHASH = keccak256(
        "Permit3(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,PermitNode permitTree)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)PermitNode(PermitNode[] nodes,ChainPermits[] permits)"
    );

    /**
     * @dev EIP-712 typehash for PermitNode structure hashing
     * Includes all nested type definitions in alphabetical order
     */
    bytes32 internal constant PERMIT_NODE_TYPEHASH = keccak256(
        "PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)"
    );

    // Constants for witness type hash strings
    string public constant PERMIT_WITNESS_TYPEHASH_STUB =
        "PermitWitness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 merkleRoot,";

    // Helper struct to avoid stack-too-deep errors
    struct WitnessParams {
        address owner;
        bytes32 salt;
        uint48 deadline;
        uint48 timestamp;
        bytes32 witness;
        bytes32 currentChainHash;
        bytes32 merkleRoot;
        bytes32 permitNodeHash;
        bytes32 typeHash;
        bytes32 signedHash;
    }

    // Context struct for tree witness permit processing
    struct TreeWitnessContext {
        bytes32 currentChainHash;
        bytes32 permitNodeHash;
        bytes32 signedHash;
    }

    /**
     * @dev Sets up EIP-712 domain separator with protocol identifiers
     * @notice Establishes the contract's domain for typed data signing
     */
    constructor() NonceManager("Permit3", "1") { }

    /**
     * @notice Direct permit execution for ERC-7702 integration
     * @dev No signature verification - caller must be the token owner
     * @param permits Array of permit operations to execute on current chain
     */
    function permit(
        AllowanceOrTransfer[] memory permits
    ) external {
        if (permits.length == 0) {
            revert EmptyArray();
        }

        ChainPermits memory chainPermits = ChainPermits({ chainId: uint64(block.chainid), permits: permits });
        _processChainPermits(msg.sender, uint48(block.timestamp), chainPermits);
    }

    /**
     * @notice Process token approvals for a single chain
     * @dev Core permit processing function for single-chain operations
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     * @param permits Array of permit operations to execute
     */
    function permit(
        AllowanceOrTransfer[] calldata permits,
        Signature calldata sig
    ) external {
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }

        if (permits.length == 0) {
            revert EmptyArray();
        }

        ChainPermits memory chainPermits = ChainPermits({ chainId: uint64(block.chainid), permits: permits });

        bytes32 signedHash = keccak256(
            abi.encode(
                PERMIT3_TYPEHASH, sig.owner, sig.salt, sig.deadline, sig.timestamp, hashChainPermits(chainPermits)
            )
        );

        _useNonce(sig.owner, sig.salt);
        _verifySignature(sig.owner, signedHash, sig.signature);
        _processChainPermits(sig.owner, sig.timestamp, chainPermits);
    }

    /**
     * @notice Process permit for multi-chain token approvals using tree structure encoding
     * @dev Reconstructs PermitNode hash from compact encoding for signature verification
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     * @param tree Tree permit data containing proofStructure, currentChainPermits, and proof
     */
    function permit(
        PermitTree calldata tree,
        Signature calldata sig
    ) external {
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }
        if (tree.currentChainPermits.chainId != uint64(block.chainid)) {
            revert WrongChainId(uint64(block.chainid), tree.currentChainPermits.chainId);
        }

        // Hash current chain's permits
        bytes32 currentChainHash = hashChainPermits(tree.currentChainPermits);

        // Reconstruct the PermitNode hash from the proof and tree structure
        bytes32 permitNodeHash =
            TreeNodeLib.computeTreeHash(PERMIT_NODE_TYPEHASH, tree.proofStructure, tree.proof, currentChainHash);

        // Verify signature with MULTICHAIN_PERMIT3_TYPEHASH
        bytes32 signedHash = keccak256(
            abi.encode(MULTICHAIN_PERMIT3_TYPEHASH, sig.owner, sig.salt, sig.deadline, sig.timestamp, permitNodeHash)
        );

        _useNonce(sig.owner, sig.salt);
        _verifySignature(sig.owner, signedHash, sig.signature);
        _processChainPermits(sig.owner, sig.timestamp, tree.currentChainPermits);
    }

    /**
     * @notice Process token approvals with witness data for single chain operations
     * @dev Handles permitWitnessTransferFrom operations with dynamic witness data
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     * @param permits Array of permit operations to execute
     * @param witness Witness data containing witness hash and type string
     */
    function permitWitness(
        AllowanceOrTransfer[] calldata permits,
        Witness calldata witness,
        Signature calldata sig
    ) external {
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }

        if (permits.length == 0) {
            revert EmptyArray();
        }

        ChainPermits memory chainPermits = ChainPermits({ chainId: uint64(block.chainid), permits: permits });

        // Validate witness type string format
        _validateWitnessTypeString(witness.witnessTypeString);

        // Get hash of permits data
        bytes32 permitDataHash = hashChainPermits(chainPermits);

        // Compute witness-specific typehash and signed hash
        bytes32 typeHash = _getWitnessTypeHash(witness.witnessTypeString);
        bytes32 signedHash = keccak256(
            abi.encode(typeHash, sig.owner, sig.salt, sig.deadline, sig.timestamp, permitDataHash, witness.witness)
        );

        _useNonce(sig.owner, sig.salt);
        _verifySignature(sig.owner, signedHash, sig.signature);
        _processChainPermits(sig.owner, sig.timestamp, chainPermits);
    }

    /**
     * @notice Process permit with witness data for multi-chain operations using tree structure
     * @dev Combines tree reconstruction with custom witness data in signature
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     * @param tree Tree permit data containing proofStructure, permits, and proof
     * @param witness Witness data containing witness hash and type string
     */
    function permitWitness(
        PermitTree calldata tree,
        Witness calldata witness,
        Signature calldata sig
    ) external {
        if (block.timestamp > sig.deadline) {
            revert SignatureExpired(sig.deadline, uint48(block.timestamp));
        }
        if (tree.currentChainPermits.chainId != uint64(block.chainid)) {
            revert WrongChainId(uint64(block.chainid), tree.currentChainPermits.chainId);
        }
        _validateWitnessTypeString(witness.witnessTypeString);

        TreeWitnessContext memory ctx = _processTreeWitnessHash(sig, tree, witness);

        _useNonce(sig.owner, sig.salt);
        _verifySignature(sig.owner, ctx.signedHash, sig.signature);
        _processChainPermits(sig.owner, sig.timestamp, tree.currentChainPermits);
    }

    /**
     * @dev Generate EIP-712 compatible hash for chain permits
     * @param chainPermits Chain-specific permit data
     * @return bytes32 Combined hash of all permit parameters
     */
    function hashChainPermits(
        ChainPermits memory chainPermits
    ) public pure returns (bytes32) {
        uint256 permitsLength = chainPermits.permits.length;
        bytes32[] memory permitHashes = new bytes32[](permitsLength);

        for (uint256 i = 0; i < permitsLength; i++) {
            permitHashes[i] = keccak256(
                abi.encode(
                    chainPermits.permits[i].modeOrExpiration,
                    chainPermits.permits[i].tokenKey,
                    chainPermits.permits[i].account,
                    chainPermits.permits[i].amountDelta
                )
            );
        }

        return keccak256(
            abi.encode(CHAIN_PERMITS_TYPEHASH, chainPermits.chainId, keccak256(abi.encodePacked(permitHashes)))
        );
    }

    /**
     * @dev Core permit processing logic that executes multiple permit operations in a single transaction
     * @dev Internal function that handles both direct permits and signature-verified permits
     * @param owner Token owner authorizing the operations
     * @param timestamp Block timestamp for validation and allowance updates
     * @param chainPermits Bundle of permit operations to process on the current chain
     * @notice Handles multiple types of operations based on modeOrExpiration value:
     *         - 0: Immediate ERC20 transfer mode - transfers ERC20 tokens directly without approval
     *         - 1: Decrease allowance mode - reduces existing allowance by specified amount
     *         - 2: Lock allowance mode - sets allowance to locked state preventing usage
     *         - 3: Unlock allowance mode - removes lock from previously locked allowance
     *         - >3: Increase allowance mode - adds to allowance with expiration timestamp
     * @notice Enforces timestamp-based locking and handles MAX_ALLOWANCE for infinite approvals
     */
    function _processChainPermits(
        address owner,
        uint48 timestamp,
        ChainPermits memory chainPermits
    ) internal {
        uint256 permitsLength = chainPermits.permits.length;
        for (uint256 i = 0; i < permitsLength; i++) {
            AllowanceOrTransfer memory p = chainPermits.permits[i];

            if (p.modeOrExpiration == uint48(PermitType.TransferERC20)) {
                // Extract address from tokenKey for transfer
                require(uint256(p.tokenKey) >> 160 == 0, InvalidTokenKeyForTransfer());

                address token = address(uint160(uint256(p.tokenKey)));
                _transferFrom(owner, p.account, p.amountDelta, token);
            } else {
                _processAllowanceOperation(owner, timestamp, p);
            }
        }
    }

    /**
     * @dev Validates that a witness type string is properly formatted for EIP-712 compliance
     * @dev Internal function used by both permitWitness variants
     * @param witnessTypeString The EIP-712 type string to validate (e.g., "CustomData(uint256 value)")
     * @notice This function ensures proper EIP-712 formatting by checking:
     *         - The string is not empty (length > 0)
     *         - The string ends with a closing parenthesis ')' for valid type definition
     * @notice Reverts with InvalidWitnessTypeString() if any validation fails
     */
    function _validateWitnessTypeString(
        string calldata witnessTypeString
    ) internal pure {
        // Validate minimum length
        if (bytes(witnessTypeString).length == 0) {
            revert InvalidWitnessTypeString(witnessTypeString);
        }

        // Validate proper ending with closing parenthesis
        uint256 witnessTypeStringLength = bytes(witnessTypeString).length;
        if (bytes(witnessTypeString)[witnessTypeStringLength - 1] != ")") {
            revert InvalidWitnessTypeString(witnessTypeString);
        }
    }

    /**
     * @dev Constructs a complete witness type hash from type string and stub for EIP-712
     * @dev Internal function that builds the full EIP-712 type string before hashing
     * @param witnessTypeString The EIP-712 witness type string suffix to append (e.g., "CustomData(uint256 value)")
     * @return typeHash The keccak256 hash of the complete EIP-712 type string
     * @notice Combines PERMIT_WITNESS_TYPEHASH_STUB with witnessTypeString to create the full type definition
     * @notice Example: stub + "CustomData(uint256 value)" becomes complete EIP-712 type string
     */
    function _getWitnessTypeHash(
        string calldata witnessTypeString
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PERMIT_WITNESS_TYPEHASH_STUB, witnessTypeString));
    }

    /**
     * @dev Internal helper to compute tree witness hash context
     * @return ctx TreeWitnessContext containing currentChainHash, permitNodeHash, and signedHash
     */
    function _processTreeWitnessHash(
        IPermit3.Signature calldata sig,
        IPermit3.PermitTree calldata tree,
        IPermit3.Witness calldata witness
    ) internal view returns (TreeWitnessContext memory ctx) {
        ctx.currentChainHash = hashChainPermits(tree.currentChainPermits);
        ctx.permitNodeHash =
            TreeNodeLib.computeTreeHash(PERMIT_NODE_TYPEHASH, tree.proofStructure, tree.proof, ctx.currentChainHash);

        ctx.signedHash = keccak256(
            abi.encode(
                _getWitnessTypeHash(witness.witnessTypeString),
                sig.owner,
                sig.salt,
                sig.deadline,
                sig.timestamp,
                ctx.permitNodeHash,
                witness.witness
            )
        );
    }

    /**
     * @dev Processes allowance-related operations for a single permit
     * @param owner Token owner authorizing the operation
     * @param timestamp Current timestamp for validation
     * @param p The permit operation to process
     */
    function _processAllowanceOperation(
        address owner,
        uint48 timestamp,
        AllowanceOrTransfer memory p
    ) private {
        // Validate tokenKey is not zero
        if (p.tokenKey == bytes32(0)) {
            revert ZeroToken();
        }

        if (p.account == address(0)) {
            revert ZeroAccount();
        }

        Allowance memory allowed = allowances[owner][p.tokenKey][p.account];

        // Validate lock status before processing
        _validateLockStatus(owner, p, allowed, p.modeOrExpiration, timestamp);

        // Process the operation based on its type
        if (p.modeOrExpiration == uint48(PermitType.Decrease)) {
            _decreaseAllowance(allowed, p.amountDelta);
        } else if (p.modeOrExpiration == uint48(PermitType.Lock)) {
            _lockAllowance(allowed, timestamp);
        } else if (p.modeOrExpiration == uint48(PermitType.Unlock)) {
            _unlockAllowance(allowed);
        } else {
            _processIncreaseOrUpdate(allowed, p, timestamp);
        }

        // Check if tokenKey represents a clean address (upper 96 bits are zero)
        // If yes, emit the regular Permit event from IPermit, otherwise emit the multi-token PermitMultiToken event
        if (uint256(p.tokenKey) >> 160 == 0) {
            // It's a clean address, emit regular Permit event for ERC20/collection-wide
            emit Permit(
                owner, address(uint160(uint256(p.tokenKey))), p.account, allowed.amount, allowed.expiration, timestamp
            );
        } else {
            // It's a hash (NFT with tokenId), emit multi-token PermitMultiToken event with tokenKey
            emit PermitMultiToken(owner, p.tokenKey, p.account, allowed.amount, allowed.expiration, timestamp);
        }

        allowances[owner][p.tokenKey][p.account] = allowed;
    }

    /**
     * @dev Validates if an operation can proceed based on lock status
     * @param owner Token owner
     * @param p Permit operation being processed
     * @param allowed Current allowance state
     * @param operationType Type of operation being performed
     * @param timestamp Current timestamp
     */
    function _validateLockStatus(
        address owner,
        AllowanceOrTransfer memory p,
        Allowance memory allowed,
        uint48 operationType,
        uint48 timestamp
    ) private pure {
        if (allowed.expiration == LOCKED_ALLOWANCE) {
            if (operationType == uint48(PermitType.Unlock)) {
                // Only allow unlock if timestamp is newer than lock timestamp
                if (timestamp <= allowed.timestamp) {
                    // Decode address from tokenKey for error message
                    revert AllowanceLocked(owner, p.tokenKey, p.account);
                }
            } else {
                // For all other operations, reject if allowance is locked
                revert AllowanceLocked(owner, p.tokenKey, p.account);
            }
        }
    }

    /**
     * @dev Decreases an allowance, handling MAX_ALLOWANCE cases
     * @param allowed Current allowance to modify
     * @param amountDelta Amount to decrease by
     */
    function _decreaseAllowance(
        Allowance memory allowed,
        uint160 amountDelta
    ) private pure {
        if (allowed.amount != MAX_ALLOWANCE || amountDelta == MAX_ALLOWANCE) {
            allowed.amount = amountDelta > allowed.amount ? 0 : allowed.amount - amountDelta;
        }
    }

    /**
     * @dev Locks an allowance to prevent further usage
     * @param allowed Allowance to lock
     * @param timestamp Current timestamp for lock tracking
     */
    function _lockAllowance(
        Allowance memory allowed,
        uint48 timestamp
    ) private pure {
        allowed.amount = 0;
        allowed.expiration = LOCKED_ALLOWANCE;
        allowed.timestamp = timestamp;
    }

    /**
     * @dev Unlocks a previously locked allowance
     * @param allowed Allowance to unlock
     */
    function _unlockAllowance(
        Allowance memory allowed
    ) private pure {
        if (allowed.expiration == LOCKED_ALLOWANCE) {
            allowed.expiration = 0;
        }
    }

    /**
     * @dev Processes increase operations and updates expiration/timestamp
     * @param allowed Current allowance to modify
     * @param p Permit operation containing new values
     * @param timestamp Current timestamp
     */
    function _processIncreaseOrUpdate(
        Allowance memory allowed,
        AllowanceOrTransfer memory p,
        uint48 timestamp
    ) private view {
        // Handle amount increase if specified
        if (p.amountDelta > 0) {
            if (allowed.amount != MAX_ALLOWANCE) {
                if (p.amountDelta == MAX_ALLOWANCE) {
                    allowed.amount = MAX_ALLOWANCE;
                } else {
                    allowed.amount += p.amountDelta;
                }
            }
        }

        // Prevent setting timestamps in the future
        if (block.timestamp < timestamp) {
            revert InvalidTimestamp(timestamp, uint48(block.timestamp));
        }

        // Update expiration and timestamp based on precedence rules
        if (timestamp > allowed.timestamp) {
            allowed.expiration = p.modeOrExpiration;
            allowed.timestamp = timestamp;
        } else if (timestamp == allowed.timestamp && p.modeOrExpiration > allowed.expiration) {
            allowed.expiration = p.modeOrExpiration;
        }
    }
}
