// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPermit
 * @notice Interface for the Permit protocol that enables gasless token approvals and transfers
 * @dev Defines core functionality for managing token permissions and transfers
 */
interface IPermit {
    /**
     * @dev Thrown when attempting to use a permit after its expiration
     * @param deadline The timestamp when the permit expired
     */
    error AllowanceExpired(uint256 deadline);

    /**
     * @dev Thrown when attempting to transfer more tokens than allowed
     * @param amount The amount that was attempted to be transferred
     */
    error InsufficientAllowance(uint256 amount);

    /**
     * @dev Represents a token and spender pair for batch operations
     * @param token The address of the token contract
     * @param spender The address approved to spend the token
     */
    struct TokenSpenderPair {
        address token;
        address spender;
    }

    /**
     * @dev Details required for token transfers
     * @param from The owner of the tokens
     * @param to The recipient of the tokens
     * @param amount The number of tokens to transfer
     * @param token The token contract address
     */
    struct AllowanceTransferDetails {
        address from;
        address to;
        uint160 amount;
        address token;
    }

    /**
     * @notice Struct storing allowance details
     * @param amount Approved amount
     * @param expiration Approval expiration timestamp
     * @param nonce Last used nonce (not sequential)
     */
    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    /**
     * @dev Emitted when permissions are set directly through approve()
     * @param owner The token owner
     * @param token The token contract address
     * @param spender The approved spender
     * @param amount The approved amount
     * @param expiration When the approval expires
     */
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration
    );

    /**
     * @dev Emitted when permissions are set through a permit signature
     * @param owner The token owner
     * @param token The token contract address
     * @param spender The approved spender
     * @param amount The approved amount
     * @param expiration When the approval expires
     * @param nonce The nonce used in the permit signature
     */
    event Permit(
        address indexed owner,
        address indexed token,
        address indexed spender,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    );

    /**
     * @dev Emitted when an approval is revoked through lockdown()
     * @param owner The token owner
     * @param token The token contract address
     * @param spender The spender whose approval was revoked
     */
    event Lockdown(address indexed owner, address token, address spender);

    /**
     * @notice Queries the current allowance for a token-spender pair
     * @param user The token owner
     * @param token The token contract address
     * @param spender The approved spender
     * @return amount The current approved amount
     * @return expiration The timestamp when the approval expires
     * @return nonce The nonce associated with this approval
     */
    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 nonce);

    /**
     * @notice Sets or updates token approval without using a signature
     * @param token The token contract address
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     * @param expiration The timestamp when the approval expires
     */
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;

    /**
     * @notice Transfers tokens from an approved address
     * @param from The owner of the tokens
     * @param to The recipient address
     * @param amount The amount to transfer
     * @param token The token contract address
     * @dev Requires prior approval from the owner to the caller (msg.sender)
     */
    function transferFrom(address from, address to, uint160 amount, address token) external;

    /**
     * @notice Executes multiple token transfers in a single transaction
     * @param transferDetails Array of transfer instructions containing owner, recipient, amount, and token
     * @dev Requires prior approval for each transfer. Reverts if any transfer fails
     */
    function transferFrom(
        AllowanceTransferDetails[] calldata transferDetails
    ) external;

    /**
     * @notice Emergency function to revoke multiple approvals at once
     * @param approvals Array of token-spender pairs to revoke
     * @dev Sets all specified approvals to zero. Useful for security incidents
     */
    function lockdown(
        TokenSpenderPair[] calldata approvals
    ) external;
}
