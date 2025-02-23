// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPermit } from "./interfaces/IPermit.sol";

/**
 * @title PermitBase
 * @notice Base implementation for token approvals and transfers
 * @dev Core functionality for managing token permissions
 */
contract PermitBase is IPermit {
    using SafeERC20 for IERC20;

    /// @dev Core data structure for tracking token permissions
    /// Maps: owner => token => spender => {amount, expiration, nonce}
    mapping(address => mapping(address => mapping(address => Allowance))) internal allowances;

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
    ) external view override returns (uint160 amount, uint48 expiration, uint48 nonce) {
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
    function approve(address token, address spender, uint160 amount, uint48 expiration) external override {
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
    function transferFrom(address from, address to, uint160 amount, address token) external override {
        Allowance storage allowed = allowances[from][token][msg.sender];
        require(allowed.expiration == 0 || block.timestamp <= allowed.expiration, AllowanceExpired(allowed.expiration));

        if (allowed.amount != type(uint160).max) {
            require(allowed.amount >= amount, InsufficientAllowance(allowed.amount));
            allowed.amount -= amount;
        }

        _transferFrom(from, to, amount, token);
    }

    /**
     * @notice Execute multiple approved transfers
     * @dev Batch version of transferFrom()
     * @param transfers Array of transfer instructions
     */
    function transferFrom(
        AllowanceTransferDetails[] calldata transfers
    ) external override {
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
    ) external override {
        for (uint256 i = 0; i < approvals.length; i++) {
            address token = approvals[i].token;
            address spender = approvals[i].spender;

            delete allowances[msg.sender][token][spender];
            emit Lockdown(msg.sender, token, spender);
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
        IERC20(token).safeTransferFrom(from, to, amount);
    }
}
