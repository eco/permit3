// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { INonceManager } from "./INonceManager.sol";
import { IPermit } from "./IPermit.sol";

/**
 * @title IPermit3
 * @notice Interface for the Permit3 cross-chain token approval and transfer system
 */
interface IPermit3 is IPermit, INonceManager {
    /**
     * @notice Enum representing the type of permit operation
     * @param Transfer Execute immediate transfer
     * @param Decrease Decrease allowance
     * @param Lock Lock allowance
     */
    enum PermitType {
        Transfer,
        Decrease,
        Lock,
        Unlock
    }

    /**
     * @notice Represents a token allowance modification or transfer operation
     * @param modeOrExpiration Mode indicators:
     *        = 0: Immediate transfer mode
     *        = 1: Decrease allowance mode
     *        = 2: Lock allowance mode
     *        = 3: Unlock allowance mode
     *        > 3: Increase allowance mode, new expiration for the allowance if the timestamp is recent
     * @param token Address of the ERC20 token
     * @param account Transfer recipient (for mode 0) or approved spender (for allowance)
     * @param amountDelta Allowance change or transfer amount:
     *        - For transfer mode: Amount to transfer
     *        - For allowance mode: Increases or decreases allowance
     *           - 0: Only updates expiration
     *           - type(uint160).max: Unlimited approval or decrease to 0.
     */
    struct AllowanceOrTransfer {
        uint48 modeOrExpiration;
        address token;
        address account;
        uint160 amountDelta;
    }

    /**
     * @notice Struct grouping permits for a specific chain
     * @param chainId Target chain identifier
     * @param permits Array of permit operations for this chain
     */
    struct ChainPermits {
        uint256 chainId;
        AllowanceOrTransfer[] permits;
    }

    /**
     * @notice Struct containing proof data for cross-chain permit operations
     * @param preHash Hash of previous chain operations, as an unbalanced merkle tree root:
     *                keccak256(keccak256(keccak256(chain1), chain2), chain3)
     * @param permits Permit operations for the current chain
     * @param followingHashes Hashes of subsequent chain operations
     * @dev Chain batches should be ordered by calldata/blob gas cost
     */
    struct Permit3Proof {
        bytes32 preHash;
        ChainPermits permits;
        bytes32[] followingHashes;
    }

    /**
     * @notice Process permit for single chain token approvals
     * @param owner Token owner address
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param chain Chain-specific permit data
     * @param signature EIP-712 signature authorizing the permits
     */
    function permit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        ChainPermits memory chain,
        bytes calldata signature
    ) external;

    /**
     * @notice Process permit for multi-chain token approvals
     * @param owner Token owner address
     * @param deadline Signature expiration timestamp
     * @param timestamp Timestamp of the permit
     * @param proof Cross-chain proof data
     * @param signature EIP-712 signature authorizing the batch
     */
    function permit(
        address owner,
        bytes32 salt,
        uint256 deadline,
        uint48 timestamp,
        Permit3Proof memory proof,
        bytes calldata signature
    ) external;
}
