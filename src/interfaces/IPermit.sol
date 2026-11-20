// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPermit
 * @notice Interface for the Permit protocol that enables gasless token approvals and transfers
 * @dev Defines core functionality for managing token permissions and transfers
 * @dev This is the subset of the Uniswap permit2 interface
 */
interface IPermit {
    /**
     * @dev Thrown when attempting to use a permit after its expiration
     * @param deadline The timestamp when the permit expired
     */
    error AllowanceExpired(uint48 deadline);

    /**
     * @dev Thrown when attempting to transfer more tokens than allowed
     * @param requestedAmount The amount that was attempted to be transferred
     * @param availableAmount The actual amount available in the allowance
     */
    error InsufficientAllowance(uint256 requestedAmount, uint256 availableAmount);

    /**
     * @notice Thrown when an allowance on a token was locked.
     * @param owner The owner of the locked allowance
     * @param tokenKey The token key identifier with the locked allowance
     * @param spender The spender whose allowance is locked
     */
    error AllowanceLocked(address owner, bytes32 tokenKey, address spender);

    /**
     * @notice Thrown when an empty array is provided where it's not allowed
     */
    error EmptyArray();

    /**
     * @notice Thrown when the token address is zero
     */
    error ZeroToken();

    /**
     * @notice Thrown when the spender address is zero
     */
    error ZeroSpender();

    /**
     * @notice Thrown when the account address is zero
     */
    error ZeroAccount();

    /**
     * @dev Thrown when an invalid amount is provided
     * @param amount The invalid amount
     */
    error InvalidAmount(uint160 amount);

    /**
     * @dev Thrown when an invalid expiration timestamp is provided
     * @param expiration The invalid expiration timestamp
     */
    error InvalidExpiration(uint48 expiration);

    /**
     * @dev Thrown when an Increase or Unlock operation carries a signed timestamp later than block.timestamp.
     *      The permit's nonce is not consumed, so the same signature can be retried once block.timestamp reaches
     *      the signed timestamp, before its deadline; its other checks still apply. Sign the latest block timestamp
     *      to avoid it.
     * @param providedTimestamp The timestamp that was provided
     * @param currentTimestamp The current block timestamp
     */
    error InvalidTimestamp(uint48 providedTimestamp, uint48 currentTimestamp);

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
     * @param timestamp The timestamp when the approval expiration was set
     */
    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 timestamp;
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
     * @param timestamp The nonce used in the permit signature
     */
    event Permit(
        address indexed owner,
        address indexed token,
        address indexed spender,
        uint160 amount,
        uint48 expiration,
        uint48 timestamp
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
     * @return timestamp The timestamp when the approval was set
     */
    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 timestamp);

    /**
     * @notice Sets or updates token approval without using a signature
     * @param token The token contract address
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     * @param expiration The timestamp when the approval expires
     */
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;

    /**
     * @notice Transfers tokens from an approved address
     * @param from The owner of the tokens
     * @param to The recipient address
     * @param amount The amount to transfer
     * @param token The token contract address
     * @dev Requires prior approval from the owner to the caller (msg.sender)
     */
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;

    /**
     * @notice Executes multiple token transfers in a single transaction
     * @param transfers Array of transfer instructions containing owner, recipient, amount, and token
     * @dev Requires prior approval for each transfer. Reverts if any transfer fails
     */
    function transferFrom(
        AllowanceTransferDetails[] calldata transfers
    ) external;

    /**
     * @notice Emergency function to lock multiple (token, account) pairs at once
     * @param approvals Array of token-spender pairs to lock
     * @dev Sets each allowance to zero and locks it. A locked pair blocks two things: transfers by that account
     *      as a spender (transferFrom and the NFT transfer functions), and Permit3 TransferERC20 operations to
     *      that account as the recipient. It does not block transfers to other recipients, including a
     *      transferFrom to the locked address by a different approved spender. A lock blocks pending signed
     *      permits but does not cancel them: once unlocked they can run again until their deadline. To cancel a
     *      signed permit, invalidate its salt with invalidateNonces. Only the owner's own call (an Unlock with
     *      msg.sender == owner) can lift a lock. A lock on one NFT/ERC1155 token id (a per-tokenId key) does not
     *      stop a spender that holds a collection-wide allowance from moving that id.
     */
    function lockdown(
        TokenSpenderPair[] calldata approvals
    ) external;
}
