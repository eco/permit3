// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";

import "../src/PermitBase.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

contract PermitBaseTest is Test {
    PermitBase permitBase;
    MockToken token;

    address owner = address(0x1);
    address spender = address(0x2);
    address recipient = address(0x3);

    uint160 constant APPROVE_AMOUNT = 1000;
    uint48 constant EXPIRATION = 1000;

    function setUp() public {
        permitBase = new PermitBase();
        token = new MockToken();

        // Setup initial token balances
        deal(address(token), owner, 10_000);
        vm.prank(owner);
        token.approve(address(permitBase), type(uint256).max);
    }

    function test_allowance() public {
        // Test initial allowance
        (uint160 amount, uint48 expiration, uint48 nonce) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);

        // Set allowance
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        // Check updated allowance
        (amount, expiration, nonce) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, APPROVE_AMOUNT);
        assertEq(expiration, EXPIRATION);
        assertEq(nonce, 0);
    }

    function test_approve() public {
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        (uint160 amount, uint48 expiration,) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, APPROVE_AMOUNT);
        assertEq(expiration, EXPIRATION);
    }

    function test_transferFrom() public {
        // Setup approval
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        // Perform transfer
        vm.prank(spender);
        permitBase.transferFrom(owner, recipient, 500, address(token));

        // Check balances
        assertEq(token.balanceOf(recipient), 500);

        // Check remaining allowance
        (uint160 amount,,) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, APPROVE_AMOUNT - 500);
    }

    function test_transferFromBatch() public {
        // Setup approval
        vm.startPrank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);
        vm.stopPrank();

        IPermit.AllowanceTransferDetails[] memory transfers = new IPermit.AllowanceTransferDetails[](2);
        transfers[0] =
            IPermit.AllowanceTransferDetails({ from: owner, to: recipient, amount: 300, token: address(token) });
        transfers[1] =
            IPermit.AllowanceTransferDetails({ from: owner, to: recipient, amount: 200, token: address(token) });

        vm.prank(spender);
        permitBase.transferFrom(transfers);

        assertEq(token.balanceOf(recipient), 500);
    }

    function test_lockdown() public {
        // Setup approvals
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: spender });

        vm.prank(owner);
        permitBase.lockdown(pairs);

        // Verify approvals are revoked
        (uint160 amount,,) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, 0);
    }

    function test_transferFromExpiredAllowance() public {
        // Setup approval with past expiration
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, 1); // expired

        vm.warp(2); // time travel past expiration

        // Attempt transfer should fail
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IPermit.AllowanceExpired.selector, 1));
        permitBase.transferFrom(owner, recipient, 500, address(token));
    }

    function test_transferFromInsufficientAllowance() public {
        // Setup small approval
        vm.prank(owner);
        permitBase.approve(address(token), spender, 100, EXPIRATION);

        // Attempt transfer larger than allowance
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IPermit.InsufficientAllowance.selector, 100));
        permitBase.transferFrom(owner, recipient, 500, address(token));
    }

    function test_maxAllowance() public {
        // Setup max allowance
        vm.prank(owner);
        permitBase.approve(address(token), spender, type(uint160).max, EXPIRATION);

        // Perform multiple transfers without reducing allowance
        vm.startPrank(spender);
        permitBase.transferFrom(owner, recipient, 500, address(token));
        permitBase.transferFrom(owner, recipient, 500, address(token));
        vm.stopPrank();

        // Check allowance remains max
        (uint160 amount,,) = permitBase.allowance(owner, address(token), spender);
        assertEq(amount, type(uint160).max);
    }

    function test_approveEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IPermit.Approval(owner, address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);
    }

    function test_lockdownEmitsEvent() public {
        vm.prank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);

        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: spender });

        vm.expectEmit(true, true, true, true);
        emit IPermit.Lockdown(owner, address(token), spender);

        vm.prank(owner);
        permitBase.lockdown(pairs);
    }

    function test_multipleLockdowns() public {
        vm.startPrank(owner);
        permitBase.approve(address(token), spender, APPROVE_AMOUNT, EXPIRATION);
        permitBase.approve(address(token), address(0x4), APPROVE_AMOUNT, EXPIRATION);

        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](2);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: spender });
        pairs[1] = IPermit.TokenSpenderPair({ token: address(token), spender: address(0x4) });

        permitBase.lockdown(pairs);
        vm.stopPrank();

        (uint160 amount1,,) = permitBase.allowance(owner, address(token), spender);
        (uint160 amount2,,) = permitBase.allowance(owner, address(token), address(0x4));
        assertEq(amount1, 0);
        assertEq(amount2, 0);
    }
}
