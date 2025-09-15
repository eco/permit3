// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    CallType,
    ERC7579Utils,
    ExecType,
    Mode,
    ModePayload,
    ModeSelector
} from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution, IERC7579Execution, IERC7579Module } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC7579ApproverModule
 * @notice ERC-7579 executor module that allows anyone to approve tokens to Permit3 on behalf of the account
 * @dev This module integrates with smart accounts using executeFromExecutor
 *      It allows permissionless approval of ERC20, ERC721, and ERC1155 tokens to the Permit3 contract
 */
contract ERC7579ApproverModule is IERC7579Module {
    /// @notice Thrown when no tokens are provided for approval
    error NoTokensProvided();

    /// @notice Thrown when a zero address is provided where it's not allowed
    error ZeroAddress();

    /// @notice Module type identifier for ERC-7579
    uint256 public constant MODULE_TYPE = 2; // Executor module

    /// @notice Name of the module
    string public constant name = "Permit3ApproverModule";

    /// @notice Version of the module
    string public constant version = "1.0.0";

    /// @notice The Permit3 contract address that will receive approvals
    address public immutable PERMIT3;

    /**
     * @notice Constructor to set the Permit3 contract address
     * @param permit3 Address of the Permit3 contract
     */
    constructor(
        address permit3
    ) {
        if (permit3 == address(0)) {
            revert ZeroAddress();
        }
        PERMIT3 = permit3;
    }

    /**
     * @notice Initialize the module for an account
     * @dev No initialization data needed for this module
     * @param data Initialization data (unused)
     */
    function onInstall(
        bytes calldata data
    ) external override {
        // No initialization needed
    }

    /**
     * @notice Deinitialize the module for an account
     * @dev No cleanup needed for this module
     * @param data Deinitialization data (unused)
     */
    function onUninstall(
        bytes calldata data
    ) external override {
        // No cleanup needed
    }

    /**
     * @notice Get the type of the module
     * @return moduleTypeId The module type identifier
     */
    function isModuleType(
        uint256 moduleTypeId
    ) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE;
    }

    /**
     * @notice Execute approval of multiple token types to Permit3
     * @dev Implements ERC-7579 Executor behavior by calling executeFromExecutor
     *      - ERC20 tokens: Uses approve(permit3, type(uint256).max)
     *      - ERC721 tokens: Uses setApprovalForAll(permit3, true)
     *      - ERC1155 tokens: Uses setApprovalForAll(permit3, true)
     * @param account The smart account executing the approvals
     * @param data Encoded arrays of token addresses for each token type
     */
    function execute(address account, bytes calldata data) external {
        // Decode the token addresses for each type
        (address[] memory erc20Tokens, address[] memory erc721Tokens, address[] memory erc1155Tokens) =
            abi.decode(data, (address[], address[], address[]));

        uint256 totalLength = erc20Tokens.length + erc721Tokens.length + erc1155Tokens.length;
        if (totalLength == 0) {
            revert NoTokensProvided();
        }

        // Create execution array for all approvals
        Execution[] memory executions = new Execution[](totalLength);
        uint256 executionIndex = 0;

        // Add ERC20 approvals
        for (uint256 i = 0; i < erc20Tokens.length; ++i) {
            if (erc20Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            executions[executionIndex++] = Execution({
                target: erc20Tokens[i],
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (PERMIT3, type(uint256).max))
            });
        }

        // Add ERC721 approvals
        for (uint256 i = 0; i < erc721Tokens.length; ++i) {
            if (erc721Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            executions[executionIndex++] = Execution({
                target: erc721Tokens[i],
                value: 0,
                callData: abi.encodeCall(IERC721.setApprovalForAll, (PERMIT3, true))
            });
        }

        // Add ERC1155 approvals
        for (uint256 i = 0; i < erc1155Tokens.length; ++i) {
            if (erc1155Tokens[i] == address(0)) {
                revert ZeroAddress();
            }
            executions[executionIndex++] = Execution({
                target: erc1155Tokens[i],
                value: 0,
                callData: abi.encodeCall(IERC1155.setApprovalForAll, (PERMIT3, true))
            });
        }

        // Encode executions for batch mode using ERC7579Utils
        bytes memory executionCalldata = ERC7579Utils.encodeBatch(executions);

        // Create proper mode encoding for batch execution that reverts on failure
        Mode mode = ERC7579Utils.encodeMode(
            ERC7579Utils.CALLTYPE_BATCH,
            ERC7579Utils.EXECTYPE_DEFAULT,
            ModeSelector.wrap(bytes4(0)),
            ModePayload.wrap(bytes22(0))
        );

        // Call executeFromExecutor on the smart account
        IERC7579Execution(account).executeFromExecutor(Mode.unwrap(mode), executionCalldata);
    }

    /**
     * @notice Check if a specific module type is supported
     * @param interfaceId The interface identifier to check
     * @return True if the interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(IERC7579Module).interfaceId;
    }
}
