// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { INonceManager } from "../src/interfaces/INonceManager.sol";
import { IPermit } from "../src/interfaces/IPermit.sol";
import { IPermit3 } from "../src/interfaces/IPermit3.sol";
import "./utils/TestBase.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title Permit3LockdownTest
 * @notice A lock on (token, account) blocks every TransferERC20 operation to `account` on every permit entry
 *         point, and only the owner's own call can lift it. A relayed signature cannot, whatever its timestamp.
 */
contract Permit3LockdownTest is TestBase {
    bytes32 constant WITNESS = bytes32(uint256(0xDEADBEEF));
    string constant WITNESS_TYPE_STRING = "bytes32 witnessData)";
    uint48 constant DEADLINE = NOW + 1 days;

    function _key() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(token))));
    }

    function _lockedError(
        address account
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(IPermit.AllowanceLocked.selector, owner, _key(), account);
    }

    function _lockdown(
        address account
    ) internal {
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: account });
        vm.prank(owner);
        permit3.lockdown(pairs);
    }

    function _op(
        uint48 mode,
        address account,
        uint160 amount
    ) internal view returns (IPermit3.AllowanceOrTransfer memory) {
        return IPermit3.AllowanceOrTransfer({
            modeOrExpiration: mode, tokenKey: _key(), account: account, amountDelta: amount
        });
    }

    function _single(
        IPermit3.AllowanceOrTransfer memory op
    ) internal view returns (IPermit3.ChainPermits memory cp) {
        IPermit3.AllowanceOrTransfer[] memory ops = new IPermit3.AllowanceOrTransfer[](1);
        ops[0] = op;
        cp = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: ops });
    }

    /// [Unlock(token, recipient), TransferERC20(token -> recipient)] under one signature
    function _unlockThenTransfer() internal view returns (IPermit3.ChainPermits memory cp) {
        IPermit3.AllowanceOrTransfer[] memory ops = new IPermit3.AllowanceOrTransfer[](2);
        ops[0] = _op(uint48(IPermit3.PermitType.Unlock), recipient, 0);
        ops[1] = _op(uint48(IPermit3.PermitType.TransferERC20), recipient, AMOUNT);
        cp = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: ops });
    }

    function _nodes() internal pure returns (bytes32[] memory nodes) {
        nodes = new bytes32[](2);
        nodes[0] = bytes32(uint256(0x1234));
        nodes[1] = bytes32(uint256(0x9abc));
    }

    function _signWitnessProof(
        IPermit3.ChainPermits memory cp,
        bytes32[] memory proof,
        uint48 ts,
        bytes32 salt
    ) internal view returns (bytes memory) {
        bytes32 root = MerkleProof.processProof(proof, permit3.hashChainPermits(cp));
        bytes32 typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), WITNESS_TYPE_STRING));
        bytes32 digest = _getDigest(keccak256(abi.encode(typeHash, owner, salt, DEADLINE, ts, root, WITNESS)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _assertLocked(
        address account
    ) internal view {
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), account);
        assertEq(amount, 0);
        assertEq(expiration, 2, "still locked");
    }

    // ---- the recipient gate holds on every entry point ----

    function test_permitTransferFrom_blockedByLockdownOnRecipient() public {
        // Cantina 3.1.2: an owner blocks a signed transfer to a given recipient by
        // calling lockdown(token, recipient), which locks the owner->token->recipient slot.
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature = _signPermit(chainPermits, DEADLINE, timestamp, SALT);

        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, timestamp, chainPermits.permits, signature);
        assertEq(token.balanceOf(recipient), 0);
        assertFalse(permit3.isNonceUsed(owner, SALT));
    }

    function test_lockdownBlocksTransferOnProofPath() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        bytes32[] memory nodes = _nodes();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signUnbalancedPermit(cp, nodes, DEADLINE, ts, SALT);

        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, ts, cp, nodes, sig);
    }

    function test_lockdownBlocksTransferOnWitnessPath() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signWitnessPermit(cp, WITNESS, WITNESS_TYPE_STRING, DEADLINE, ts, SALT);

        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp.permits, WITNESS, WITNESS_TYPE_STRING, sig);
    }

    function test_lockdownBlocksTransferOnWitnessProofPath() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        bytes32[] memory nodes = _nodes();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signWitnessProof(cp, nodes, ts, SALT);

        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp, nodes, WITNESS, WITNESS_TYPE_STRING, sig);
    }

    function test_lockdownBlocksOwnerDirectPermitTransfer() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        vm.prank(owner);
        permit3.permit(cp.permits);
        assertEq(token.balanceOf(recipient), 0);
    }

    function test_lockPermitOnRecipientBlocksTransfer() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        // A Lock-mode permit writes the same slot as lockdown()
        vm.prank(owner);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Lock), recipient, 0)).permits);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
    }

    // ---- what the gate does not do ----

    function test_lockOnAnotherAccountDoesNotBlockTransfer() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit(); // AMOUNT to `recipient`
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        _lockdown(spender); // a lock on another account

        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertEq(token.balanceOf(recipient), AMOUNT, "a transfer to a recipient that is not locked goes through");
    }

    function test_otherSpenderTransferFromToLockedAddressIsNotBlocked() public {
        vm.prank(owner);
        permit3.approve(address(token), spender, AMOUNT, 0);

        _lockdown(recipient);

        // Allowance transfers read the caller's slot, never `to`
        vm.prank(spender);
        permit3.transferFrom(owner, recipient, AMOUNT, address(token));
        assertEq(token.balanceOf(recipient), AMOUNT);

        // The locked address itself cannot be approved as a spender
        vm.expectRevert(_lockedError(recipient));
        vm.prank(owner);
        permit3.approve(address(token), recipient, AMOUNT, 0);
    }

    function test_blockedPermitKeepsNonceAndRunsAfterOwnerUnlocks() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        _lockdown(recipient);
        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertFalse(permit3.isNonceUsed(owner, SALT), "the blocked permit kept its nonce");

        // The owner lifts the lock without cancelling the signature first
        vm.prank(owner);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Unlock), recipient, 0)).permits);

        // The same signature runs again until its deadline: a lock blocks, it does not cancel
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertEq(token.balanceOf(recipient), AMOUNT);
    }

    function test_invalidateNoncesCancelsBlockedPermit() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        uint48 ts = uint48(block.timestamp);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        _lockdown(recipient);

        // Cancel the signature, then lift the lock
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = SALT;
        vm.startPrank(owner);
        permit3.invalidateNonces(salts);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Unlock), recipient, 0)).permits);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(INonceManager.NonceAlreadyUsed.selector, owner, SALT));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertEq(token.balanceOf(recipient), 0);
    }

    // ---- only the owner's own call lifts a lock ----

    /// Signed before the lockdown, dated after it: once its timestamp is reached it still cannot lift the lock
    function test_preSignedUnlockAndTransferBatchCannotLiftLockdown() public {
        IPermit3.ChainPermits memory cp = _unlockThenTransfer();
        uint48 ts = NOW + 1000;
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        _lockdown(recipient); // lock timestamp = now, below ts
        vm.warp(ts);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertEq(token.balanceOf(recipient), 0);
        _assertLocked(recipient);
    }

    /// Two signatures instead of one batch: an Unlock-only permit, then a Transfer-only permit
    function test_separateUnlockPermitThenTransferPermitCannotLiftLockdown() public {
        IPermit3.ChainPermits memory unlockCp = _single(_op(uint48(IPermit3.PermitType.Unlock), recipient, 0));
        IPermit3.ChainPermits memory transferCp = _createBasicTransferPermit();

        uint48 ts = NOW + 1000;
        bytes memory unlockSig = _signPermit(unlockCp, DEADLINE, ts, bytes32(uint256(1)));
        bytes memory transferSig = _signPermit(transferCp, DEADLINE, ts, bytes32(uint256(2)));

        _lockdown(recipient);
        vm.warp(ts);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, bytes32(uint256(1)), DEADLINE, ts, unlockCp.permits, unlockSig);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, bytes32(uint256(2)), DEADLINE, ts, transferCp.permits, transferSig);
        assertEq(token.balanceOf(recipient), 0);
    }

    function test_olderUnlockBatchIsBlockedByLaterLockdown() public {
        IPermit3.ChainPermits memory cp = _unlockThenTransfer();
        uint48 ts = NOW;
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.warp(ts + 10);
        _lockdown(recipient);

        vm.expectRevert(_lockedError(recipient));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
    }

    /// A lock set by a relayed Lock permit is just as final: a pre-signed Unlock dated after it cannot lift it
    function test_preSignedUnlockCannotLiftSignedLock() public {
        IPermit3.ChainPermits memory unlockCp = _single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0));
        uint48 unlockTs = NOW + 500;
        bytes memory unlockSig = _signPermit(unlockCp, DEADLINE, unlockTs, bytes32(uint256(1)));

        IPermit3.ChainPermits memory lockCp = _single(_op(uint48(IPermit3.PermitType.Lock), spender, 0));
        uint48 lockTs = NOW;
        bytes memory lockSig = _signPermit(lockCp, DEADLINE, lockTs, bytes32(uint256(2)));
        permit3.permit(owner, bytes32(uint256(2)), DEADLINE, lockTs, lockCp.permits, lockSig);

        vm.warp(unlockTs);
        vm.expectRevert(_lockedError(spender));
        permit3.permit(owner, bytes32(uint256(1)), DEADLINE, unlockTs, unlockCp.permits, unlockSig);
        _assertLocked(spender);
    }

    function test_relayedUnlockRejectedOnProofPath() public {
        _lockdown(spender);
        vm.warp(NOW + 1); // a relayed Unlock newer than the lock: it would lift the lock under a timestamp rule

        IPermit3.ChainPermits memory cp = _single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0));
        bytes32[] memory nodes = _nodes();
        uint48 ts = NOW + 1;
        bytes memory sig = _signUnbalancedPermit(cp, nodes, DEADLINE, ts, SALT);

        vm.expectRevert(_lockedError(spender));
        permit3.permit(owner, SALT, DEADLINE, ts, cp, nodes, sig);
    }

    function test_relayedUnlockRejectedOnWitnessPath() public {
        _lockdown(spender);
        vm.warp(NOW + 1); // a relayed Unlock newer than the lock: it would lift the lock under a timestamp rule

        IPermit3.ChainPermits memory cp = _single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0));
        uint48 ts = NOW + 1;
        bytes memory sig = _signWitnessPermit(cp, WITNESS, WITNESS_TYPE_STRING, DEADLINE, ts, SALT);

        vm.expectRevert(_lockedError(spender));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp.permits, WITNESS, WITNESS_TYPE_STRING, sig);
    }

    /// A relayer whose transaction the owner originated (tx.origin == owner) is still not the owner's own call
    function test_relayedUnlockRejectedEvenWhenTxOriginIsOwner() public {
        _lockdown(spender);
        vm.warp(NOW + 1);

        IPermit3.ChainPermits memory cp = _single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0));
        bytes memory sig = _signPermit(cp, DEADLINE, NOW + 1, SALT);

        vm.prank(address(0xBEEF), owner);
        vm.expectRevert(_lockedError(spender));
        permit3.permit(owner, SALT, DEADLINE, NOW + 1, cp.permits, sig);
    }

    /// The owner's own call lifts a lock only with Unlock: its other operations on the locked pair still revert
    function test_ownerOwnIncreaseDecreaseAndLockOnLockedPairRevert() public {
        _lockdown(spender);

        uint48[3] memory modes = [NOW + 1 days, uint48(IPermit3.PermitType.Decrease), uint48(IPermit3.PermitType.Lock)];
        for (uint256 i = 0; i < modes.length; i++) {
            vm.expectRevert(_lockedError(spender));
            vm.prank(owner);
            permit3.permit(_single(_op(modes[i], spender, 100)).permits);
        }
        _assertLocked(spender);
    }

    /// The approver modules can make an owner's account call any target, but only with approve(address,uint256)
    /// and setApprovalForAll(address,bool). Permit3 has neither selector and no fallback.
    function test_approverModuleSelectorsDoNotReachPermit3() public {
        (bool approveOk,) = address(permit3).call(abi.encodeWithSelector(bytes4(0x095ea7b3), spender, uint256(1)));
        (bool approvalForAllOk,) = address(permit3).call(abi.encodeWithSelector(bytes4(0xa22cb465), spender, true));
        assertFalse(approveOk, "approve(address,uint256) must not exist on Permit3");
        assertFalse(approvalForAllOk, "setApprovalForAll(address,bool) must not exist on Permit3");
    }

    // ---- the owner's own call ----

    function test_ownerDirectUnlockLiftsLockdownInSameSecond() public {
        _lockdown(spender);

        vm.prank(owner);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0)).permits);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "unlocked");

        // The owner can approve the spender again
        vm.prank(owner);
        permit3.approve(address(token), spender, AMOUNT, 0);
        (uint160 amount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, AMOUNT);
    }

    function test_ownerSelfSubmittedSignedUnlockLiftsLock() public {
        _lockdown(spender);

        // Same second as the lockdown: the owner's own call does not depend on the timestamp
        IPermit3.ChainPermits memory cp = _single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0));
        uint48 ts = NOW;
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.prank(owner);
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "unlocked");
    }

    function test_ownerDirectUnlockLiftsSignedLock() public {
        IPermit3.ChainPermits memory lockCp = _single(_op(uint48(IPermit3.PermitType.Lock), spender, 0));
        uint48 ts = uint48(block.timestamp);
        bytes memory lockSig = _signPermit(lockCp, DEADLINE, ts, SALT);
        permit3.permit(owner, SALT, DEADLINE, ts, lockCp.permits, lockSig);
        _assertLocked(spender);

        vm.prank(owner);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0)).permits);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "unlocked");
    }

    function test_ownerDirectUnlockLiftsPerTokenIdLock() public {
        bytes32 nftKey = keccak256(abi.encodePacked(address(token), uint256(7)));
        IPermit3.AllowanceOrTransfer memory op = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Lock), tokenKey: nftKey, account: spender, amountDelta: 0
        });
        IPermit3.ChainPermits memory lockCp = _single(op);
        uint48 ts = uint48(block.timestamp);
        bytes memory lockSig = _signPermit(lockCp, DEADLINE, ts, SALT);
        permit3.permit(owner, SALT, DEADLINE, ts, lockCp.permits, lockSig);

        // lockdown() cannot reach a per-tokenId key; the owner's own Unlock can
        op.modeOrExpiration = uint48(IPermit3.PermitType.Unlock);
        vm.prank(owner);
        permit3.permit(_single(op).permits);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender, 7);
        assertEq(expiration, 0, "unlocked");
    }

    /// The last representable second: a Lock stored at type(uint48).max is still lifted by the owner's own call
    function test_ownerDirectUnlockLiftsLockStoredAtUint48Max() public {
        vm.warp(type(uint48).max);
        uint48 maxTs = type(uint48).max;

        IPermit3.ChainPermits memory lockCp = _single(_op(uint48(IPermit3.PermitType.Lock), spender, 0));
        bytes memory lockSig = _signPermit(lockCp, maxTs, maxTs, SALT);
        permit3.permit(owner, SALT, maxTs, maxTs, lockCp.permits, lockSig);
        (,, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(storedTs, maxTs);

        vm.prank(owner);
        permit3.permit(_single(_op(uint48(IPermit3.PermitType.Unlock), spender, 0)).permits);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "unlocked");
    }
}
