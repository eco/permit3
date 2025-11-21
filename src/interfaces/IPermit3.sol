// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { INonceManager } from "./INonceManager.sol";
import { IPermit } from "./IPermit.sol";

/**
 * @title IPermit3
 * @notice Interface for the Permit3 cross-chain token approval and transfer system using UnbalancedProofs
 */
interface IPermit3 is IPermit, INonceManager {
    /**
     * @notice Thrown when an invalid token key is used for transfer
     */
    error InvalidTokenKeyForTransfer();

    /**
     * @notice Enum representing the type of permit operation
     * @param TransferERC20 Execute immediate ERC20 transfer
     * @param Decrease Decrease allowance
     * @param Lock Lock allowance
     * @param Unlock Unlock previously locked allowance
     */
    enum PermitType {
        TransferERC20,
        Decrease,
        Lock,
        Unlock
    }

    /**
     * @notice Represents a token allowance modification or transfer operation
     * @param modeOrExpiration Mode indicators:
     *        = 0: Immediate ERC20 transfer mode
     *        = 1: Decrease allowance mode
     *        = 2: Lock allowance mode
     *        = 3: UnLock allowance mode
     *        > 3: Increase allowance mode, new expiration for the allowance if the timestamp is recent
     * @param tokenKey Encoded token identifier (bytes32):
     *        - For ERC20: bytes32(uint256(uint160(address)))
     *        - For ERC721/ERC1155: keccak256(abi.encodePacked(token, tokenId))
     * @param account Transfer recipient (for ERC20 transfer mode) or approved spender (for allowance)
     * @param amountDelta Allowance change or transfer amount:
     *        - For ERC20 transfer mode: Amount to transfer
     *        - For allowance mode: Increases or decreases allowance
     *           - 0: Only updates expiration
     *           - type(uint160).max: Unlimited approval or decrease to 0.
     */
    struct AllowanceOrTransfer {
        uint48 modeOrExpiration;
        bytes32 tokenKey;
        address account;
        uint160 amountDelta;
    }

    /**
     * @notice Struct grouping permits for a specific chain
     * @param chainId Target chain identifier
     * @param permits Array of permit operations for this chain
     */
    struct ChainPermits {
        uint64 chainId;
        AllowanceOrTransfer[] permits;
    }

    /**
     * @notice Reusable struct for permit signature data
     * @param owner Token owner address
     * @param salt Unique salt for replay protection
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param signature EIP-712 signature bytes
     */
    struct Signature {
        address owner;
        bytes32 salt;
        uint48 deadline;
        uint48 timestamp;
        bytes signature;
    }

    /**
     * @notice Nested structure for UI-readable tree representation
     * @dev Used in EIP-712 signatures to provide transparency to users about what they're signing
     * @dev Can represent either leaf nodes (ChainPermits) or internal tree nodes (nested levels)
     * @dev Both arrays should be ordered by hash value as merkle tree construction requires
     * @param nodes Child tree nodes for internal nodes (ordered by hash value)
     * @param permits Leaf nodes showing actual chain permits for user visibility (ordered by hash value)
     */
    struct PermitNode {
        PermitNode[] nodes;
        ChainPermits[] permits;
    }

    /**
     * @notice Input struct for tree-based permits containing tree structure data
     * @param currentChainPermits Permit operations for the current chain
     * @param proofStructure Compact tree encoding
     * @param proof Array of hashes for proof reconstruction
     */
    struct PermitTree {
        ChainPermits currentChainPermits;
        bytes32 proofStructure;
        bytes32[] proof;
    }

    /**
     * @notice Witness data for permit operations
     * @param witness Additional witness data hash
     * @param witnessTypeString EIP-712 type definition for witness data
     */
    struct Witness {
        bytes32 witness;
        string witnessTypeString;
    }

    // ============================================
    // FUNCTIONS
    // ============================================

    /**
     * @notice Direct permit execution for ERC-7702 integration
     * @dev No signature verification - caller must be the token owner
     * @param permits Array of permit operations to execute on current chain
     */
    function permit(
        AllowanceOrTransfer[] memory permits
    ) external;

    /**
     * @notice Process permit for single chain token approvals
     * @param permits Array of permit operations to execute
     * @param sig Permit signature data containing owner, salt, deadline, timestamp, and signature
     */
    function permit(
        AllowanceOrTransfer[] calldata permits,
        Signature calldata sig
    ) external;

    /**
     * @notice Process permit for multi-chain token approvals using tree structure encoding
     * @dev Uses compact proofStructure encoding to reconstruct merkle tree and validate permits
     * @param tree Tree permit data containing proofStructure, currentChainPermits, and proof
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     */
    function permit(
        PermitTree calldata tree,
        Signature calldata sig
    ) external;

    /**
     * @notice Process permit with additional witness data for single chain operations
     * @param permits Array of permit operations to execute
     * @param witness Witness data containing witness hash and type string
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     */
    function permitWitness(
        AllowanceOrTransfer[] calldata permits,
        Witness calldata witness,
        Signature calldata sig
    ) external;

    /**
     * @notice Process permit with additional witness data for multi-chain operations using tree structure
     * @param tree Tree permit data containing proofStructure, permits, and proof
     * @param witness Witness data containing witness hash and type string
     * @param sig Permit signature data (owner, salt, deadline, timestamp, signature)
     */
    function permitWitness(
        PermitTree calldata tree,
        Witness calldata witness,
        Signature calldata sig
    ) external;

    /**
     * @notice Hashes chain permits data for cross-chain operations
     * @param chainPermits Chain-specific permit data
     * @return bytes32 Combined hash of all permit parameters
     */
    function hashChainPermits(
        ChainPermits memory chainPermits
    ) external pure returns (bytes32);
}
