// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC7702TokenApprover } from "../src/ERC7702TokenApprover.sol";
import { Permit3 } from "../src/Permit3.sol";
import { IPermit3 } from "../src/interfaces/IPermit3.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Test } from "forge-std/Test.sol";

// Mock ERC20 for testing
contract MockERC20 {
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    bool public shouldFailApproval = false;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (shouldFailApproval) {
            return false;
        }
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function setShouldFailApproval(
        bool _shouldFail
    ) external {
        shouldFailApproval = _shouldFail;
    }
}

// Contract that simulates EOA behavior when delegatecalling to ERC7702TokenApprover
contract MockEOA {
    ERC7702TokenApprover public immutable approver;

    constructor(
        ERC7702TokenApprover _approver
    ) {
        approver = _approver;
    }

    // Simulates what would happen when EOA delegatecalls to ERC7702TokenApprover
    function simulateERC7702Approval(
        address[] calldata tokens
    ) external {
        // In real ERC-7702, this would be a delegatecall from the EOA
        // For testing purposes, we directly call the approver's logic
        bytes memory data = abi.encodeWithSelector(approver.approve.selector, tokens);
        (bool success,) = address(approver).delegatecall(data);
        require(success, "ERC7702 simulation failed");
    }

}

contract ERC7702TokenApproverTest is Test {
    ERC7702TokenApprover public approver;
    Permit3 public permit3;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;
    MockEOA public mockEOA;

    address public user = address(0xBEEF);
    address public spender = address(0xCAFE);

    function setUp() public {
        permit3 = new Permit3();
        approver = new ERC7702TokenApprover(address(permit3));
        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");
        token3 = new MockERC20("Token3", "TK3");
        mockEOA = new MockEOA(approver);
    }

    function test_Constructor() public view {
        assertEq(approver.PERMIT3(), address(permit3));
    }

    function test_Approve_SingleToken() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        // Skip event check due to msg.sender context in delegatecall tests
        mockEOA.simulateERC7702Approval(tokens);

        assertEq(token1.allowance(address(mockEOA), address(permit3)), type(uint256).max);
    }

    function test_Approve_MultipleTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        // Skip event check due to msg.sender context in delegatecall tests
        mockEOA.simulateERC7702Approval(tokens);

        assertEq(token1.allowance(address(mockEOA), address(permit3)), type(uint256).max);
        assertEq(token2.allowance(address(mockEOA), address(permit3)), type(uint256).max);
        assertEq(token3.allowance(address(mockEOA), address(permit3)), type(uint256).max);
    }

    function test_Approve_EmptyArray() public {
        address[] memory tokens = new address[](0);

        // Need to catch the revert from inside the delegatecall
        vm.expectRevert("ERC7702 simulation failed");
        mockEOA.simulateERC7702Approval(tokens);
    }

    function test_Approve_ApprovalFails() public {
        token1.setShouldFailApproval(true);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        vm.expectRevert("ERC7702 simulation failed");
        mockEOA.simulateERC7702Approval(tokens);
    }

    function test_Approve_PartialFailure() public {
        // Set token2 to fail approval
        token2.setShouldFailApproval(true);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        vm.expectRevert("ERC7702 simulation failed");
        mockEOA.simulateERC7702Approval(tokens);

        // When delegatecall reverts, all state changes are reverted
        // So no tokens should have approvals set
        assertEq(token1.allowance(address(mockEOA), address(permit3)), 0);
        assertEq(token2.allowance(address(mockEOA), address(permit3)), 0);
        assertEq(token3.allowance(address(mockEOA), address(permit3)), 0);
    }

    function test_Approve_OverwritesExistingAllowance() public {
        // Set initial allowance through mock EOA
        vm.prank(address(mockEOA));
        token1.approve(address(permit3), 1000);
        assertEq(token1.allowance(address(mockEOA), address(permit3)), 1000);

        // Approve should overwrite with infinite
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        mockEOA.simulateERC7702Approval(tokens);

        assertEq(token1.allowance(address(mockEOA), address(permit3)), type(uint256).max);
    }

    function test_Approve_DifferentEOAs() public {
        MockEOA mockEOA2 = new MockEOA(approver);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        // First EOA approves
        mockEOA.simulateERC7702Approval(tokens);

        // Second EOA approves
        mockEOA2.simulateERC7702Approval(tokens);

        // Both should have infinite allowance
        assertEq(token1.allowance(address(mockEOA), address(permit3)), type(uint256).max);
        assertEq(token1.allowance(address(mockEOA2), address(permit3)), type(uint256).max);
    }

    function testFuzz_Approve(
        uint8 tokenCount
    ) public {
        vm.assume(tokenCount > 0 && tokenCount <= 10);

        address[] memory tokens = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = address(new MockERC20("Token", "TK"));
        }

        mockEOA.simulateERC7702Approval(tokens);

        for (uint256 i = 0; i < tokenCount; i++) {
            assertEq(IERC20(tokens[i]).allowance(address(mockEOA), address(permit3)), type(uint256).max);
        }
    }

    // Test direct contract calls (non-ERC7702 scenario)
    // Note: When called directly, the approve calls are made BY the approver contract
    // So the approver contract gets the allowances, which is not useful behavior
    function test_DirectCall_Approve() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        approver.approve(tokens);

        // The allowance will be set for the approver contract (not useful)
        assertEq(token1.allowance(address(approver), address(permit3)), type(uint256).max);
    }

}
