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
     * @notice Struct representing a single token approval or transfer operation
     * @param transferOrExpiration Special values: 1 = immediate transfer, 0 = permanent approval
     *                            Any value > 1 represents an expiration timestamp
     * @param token Address of the token contract
     * @param spender Address approved to spend tokens
     * @param amount Special values: 0 = remove approval, type(uint160).max = unlimited approval
     *               Otherwise represents the approved amount
     */
    struct SpendTransferPermit {
        uint48 transferOrExpiration;
        address token;
        address spender;
        uint160 amount;
    }

    /**
     * @notice Struct grouping permits for a specific chain
     * @param chainId Target chain identifier
     * @param nonce Random nonce value (not sequential)
     * @param permits Array of permit operations for this chain
     */
    struct ChainPermits {
        uint64 chainId;
        uint48 nonce;
        SpendTransferPermit[] permits;
    }

    /**
     * @notice Struct containing proof data for cross-chain permit operations
     * @param preHash Hash of previous chain operations, chained as:
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
     * @param permits Chain-specific permit data
     * @param signature EIP-712 signature authorizing the permits
     */
    function permit(address owner, uint256 deadline, ChainPermits memory permits, bytes calldata signature) external;

    /**
     * @notice Process permit for multi-chain token approvals
     * @param owner Token owner address
     * @param deadline Signature expiration timestamp
     * @param batch Cross-chain proof data
     * @param signature EIP-712 signature authorizing the batch
     */
    function permit(address owner, uint256 deadline, Permit3Proof memory batch, bytes calldata signature) external;
}
