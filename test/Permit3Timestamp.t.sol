// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit } from "../src/interfaces/IPermit.sol";
import { IPermit3 } from "../src/interfaces/IPermit3.sol";
import "./utils/TestBase.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title Permit3TimestampTest
 * @notice No allowance operation stores or compares a signed timestamp that is later than block.timestamp.
 *         Increase and Unlock revert with InvalidTimestamp, Lock stores block.timestamp instead, Decrease
 *         ignores the timestamp, and TransferERC20 operations never read it.
 */
contract Permit3TimestampTest is TestBase {
    bytes32 constant WITNESS = bytes32(uint256(0xDEADBEEF));
    string constant WITNESS_TYPE_STRING = "bytes32 witnessData)";
    uint48 constant DEADLINE = NOW + 1 days;
    uint48 constant LATER_EXPIRATION = NOW + 2 days;

    function _key() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(token))));
    }

    function _invalidTimestamp(
        uint48 ts
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(IPermit.InvalidTimestamp.selector, ts, uint48(block.timestamp));
    }

    function _lockdown(
        address account
    ) internal {
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: account });
        vm.prank(owner);
        permit3.lockdown(pairs);
    }

    /// One allowance operation on (token, spender)
    function _one(
        uint48 mode,
        uint160 amount
    ) internal view returns (IPermit3.ChainPermits memory cp) {
        IPermit3.AllowanceOrTransfer[] memory ops = new IPermit3.AllowanceOrTransfer[](1);
        ops[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: mode, tokenKey: _key(), account: spender, amountDelta: amount
        });
        cp = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: ops });
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

    function _otherChainLeaf() internal pure returns (bytes32[] memory nodes) {
        nodes = new bytes32[](1);
        nodes[0] = keccak256("other chain leaf");
    }

    // ---- Increase and Unlock reject a future timestamp ----

    function test_increaseWithFutureTimestampReverts() public {
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (uint160 amount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 0, "nothing was granted");
    }

    function test_unlockWithFutureTimestampReverts() public {
        _lockdown(spender);

        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2, "still locked");
    }

    function test_futureTimestampRevertIsRetryable() public {
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        uint48 ts = NOW + 30; // the signer's clock is 30 s ahead of the chain
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertFalse(permit3.isNonceUsed(owner, SALT), "the reverted permit did not consume its nonce");

        // The same signature succeeds once block.timestamp reaches the signed timestamp
        vm.warp(ts);
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        (uint160 amount, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 500);
        assertEq(expiration, LATER_EXPIRATION);
        assertEq(storedTs, ts);
    }

    // ---- Lock stores block.timestamp instead of a future timestamp ----

    function test_lockWithFutureTimestampStoresBlockTimestamp() public {
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        // The Permit event reports the stored timestamp
        vm.expectEmit(true, true, true, true, address(permit3));
        emit IPermit.Permit(owner, address(token), spender, 0, 2, uint48(block.timestamp));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (uint160 amount, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 0);
        assertEq(expiration, 2, "locked");
        assertEq(storedTs, uint48(block.timestamp), "block.timestamp, not the signed timestamp");
    }

    function test_lockWithMaxTimestampStoresBlockTimestampAndOwnerCanUnlock() public {
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        bytes memory sig = _signPermit(cp, DEADLINE, type(uint48).max, SALT);
        permit3.permit(owner, SALT, DEADLINE, type(uint48).max, cp.permits, sig);

        uint48 lockedAt = uint48(block.timestamp);
        (, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2, "locked");
        assertEq(storedTs, lockedAt, "type(uint48).max is not stored");

        // One second later the owner's own Unlock lifts the lock
        vm.warp(lockedAt + 1);
        IPermit3.ChainPermits memory unlockCp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        vm.prank(owner);
        permit3.permit(unlockCp.permits);

        (, expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "unlocked");
    }

    function test_clockSkewedEmergencyLockLandsImmediately() public {
        vm.prank(owner);
        permit3.approve(address(token), spender, type(uint160).max, 0);

        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        uint48 ts = uint48(block.timestamp + 30); // the signer's clock is 30 s ahead of the chain
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        // The spender is stopped at once
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IPermit.AllowanceLocked.selector, owner, _key(), spender));
        permit3.transferFrom(owner, spender, AMOUNT, address(token));
    }

    function test_futureLockOnProofPathStoresBlockTimestamp() public {
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        bytes32[] memory nodes = _otherChainLeaf();
        uint48 ts = uint48(block.timestamp + 1000);
        bytes memory sig = _signUnbalancedPermit(cp, nodes, DEADLINE, ts, SALT);

        permit3.permit(owner, SALT, DEADLINE, ts, cp, nodes, sig);

        (, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2);
        assertEq(storedTs, uint48(block.timestamp));
    }

    // ---- Decrease ignores the timestamp ----

    function test_decreaseWithFutureTimestampIsApplied() public {
        vm.prank(owner);
        permit3.approve(address(token), spender, 500, 0);
        (,, uint48 approvedAt) = permit3.allowance(owner, address(token), spender);

        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Decrease), 100);
        uint48 ts = uint48(block.timestamp + 30);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        // The Permit event reports the signed timestamp of the Decrease; nothing stores it
        vm.expectEmit(true, true, true, true, address(permit3));
        emit IPermit.Permit(owner, address(token), spender, 400, 0, ts);
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (uint160 amount, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 400, "decreased at once");
        assertEq(expiration, 0);
        assertEq(storedTs, approvedAt, "a Decrease does not store its timestamp");
    }

    // ---- boundaries ----

    function test_timestampEqualToBlockTimestampIsAccepted() public {
        uint48 ts = uint48(block.timestamp);

        // Increase
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, bytes32(uint256(1)));
        permit3.permit(owner, bytes32(uint256(1)), DEADLINE, ts, cp.permits, sig);
        (uint160 amount,, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 500);
        assertEq(storedTs, ts);

        // Decrease
        cp = _one(uint48(IPermit3.PermitType.Decrease), 100);
        sig = _signPermit(cp, DEADLINE, ts, bytes32(uint256(2)));
        permit3.permit(owner, bytes32(uint256(2)), DEADLINE, ts, cp.permits, sig);
        (amount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 400);

        // Unlock of an allowance that is not locked changes nothing
        cp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        sig = _signPermit(cp, DEADLINE, ts, bytes32(uint256(3)));
        permit3.permit(owner, bytes32(uint256(3)), DEADLINE, ts, cp.permits, sig);
        (amount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 400);

        // Lock
        cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        sig = _signPermit(cp, DEADLINE, ts, bytes32(uint256(4)));
        permit3.permit(owner, bytes32(uint256(4)), DEADLINE, ts, cp.permits, sig);
        (, uint48 expiration, uint48 lockTs) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2);
        assertEq(lockTs, ts);
    }

    // ---- every entry point ----

    function test_futureIncreaseOnProofPathReverts() public {
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        bytes32[] memory nodes = _otherChainLeaf();
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signUnbalancedPermit(cp, nodes, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp, nodes, sig);
    }

    function test_futureIncreaseOnWitnessPathReverts() public {
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signWitnessPermit(cp, WITNESS, WITNESS_TYPE_STRING, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp.permits, WITNESS, WITNESS_TYPE_STRING, sig);
    }

    function test_futureIncreaseOnWitnessProofPathReverts() public {
        IPermit3.ChainPermits memory cp = _one(LATER_EXPIRATION, 500);
        bytes32[] memory nodes = _otherChainLeaf();
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signWitnessProof(cp, nodes, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp, nodes, WITNESS, WITNESS_TYPE_STRING, sig);
    }

    function test_futureUnlockOnProofPathReverts() public {
        _lockdown(spender);
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        bytes32[] memory nodes = _otherChainLeaf();
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signUnbalancedPermit(cp, nodes, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp, nodes, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2, "still locked");
    }

    function test_futureUnlockOnWitnessPathReverts() public {
        _lockdown(spender);
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signWitnessPermit(cp, WITNESS, WITNESS_TYPE_STRING, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp.permits, WITNESS, WITNESS_TYPE_STRING, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2, "still locked");
    }

    function test_futureUnlockOnWitnessProofPathReverts() public {
        _lockdown(spender);
        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Unlock), 0);
        bytes32[] memory nodes = _otherChainLeaf();
        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signWitnessProof(cp, nodes, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permitWitness(owner, SALT, DEADLINE, ts, cp, nodes, WITNESS, WITNESS_TYPE_STRING, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2, "still locked");
    }

    // ---- batches and transfers ----

    function test_mixedBatchWithFutureIncreaseRevertsAtomically() public {
        IPermit3.AllowanceOrTransfer[] memory ops = new IPermit3.AllowanceOrTransfer[](2);
        ops[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.TransferERC20),
            tokenKey: _key(),
            account: recipient,
            amountDelta: AMOUNT
        });
        ops[1] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: LATER_EXPIRATION, tokenKey: _key(), account: spender, amountDelta: 500
        });
        IPermit3.ChainPermits memory cp = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: ops });

        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);
        assertEq(token.balanceOf(recipient), 0, "the transfer is rolled back");
        assertFalse(permit3.isNonceUsed(owner, SALT), "the nonce is not consumed");
    }

    /// The Lock clamp is local to the Lock: a future Increase in the same permit still reverts the whole permit
    function test_futureIncreaseRevertsBatchWithLockAtomically() public {
        IPermit3.AllowanceOrTransfer[] memory ops = new IPermit3.AllowanceOrTransfer[](2);
        ops[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Lock), tokenKey: _key(), account: spender, amountDelta: 0
        });
        ops[1] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: LATER_EXPIRATION, tokenKey: _key(), account: recipient, amountDelta: 500
        });
        IPermit3.ChainPermits memory cp = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: ops });

        uint48 ts = uint48(block.timestamp + 1);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        vm.expectRevert(_invalidTimestamp(ts));
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 0, "no lock was stored");
    }

    function test_transferOnlyPermitIgnoresTimestamp() public {
        IPermit3.ChainPermits memory cp = _createBasicTransferPermit();
        bytes memory sig = _signPermit(cp, DEADLINE, type(uint48).max, SALT);

        permit3.permit(owner, SALT, DEADLINE, type(uint48).max, cp.permits, sig);
        assertEq(token.balanceOf(recipient), AMOUNT);
    }

    // ---- property: a stored timestamp is never later than block.timestamp ----

    function testFuzz_storedTimestampNeverExceedsBlockTimestamp(
        uint8 modeSeed,
        uint48 skew
    ) public {
        uint48[4] memory modes = [
            uint48(IPermit3.PermitType.Decrease),
            uint48(IPermit3.PermitType.Lock),
            uint48(IPermit3.PermitType.Unlock),
            LATER_EXPIRATION
        ];
        uint48 mode = modes[modeSeed % 4];
        uint48 ts = uint48(block.timestamp) + uint48(bound(skew, 0, type(uint48).max - block.timestamp));

        vm.prank(owner);
        permit3.approve(address(token), spender, 500, 0);

        IPermit3.ChainPermits memory cp = _one(mode, 100);
        bytes memory sig = _signPermit(cp, DEADLINE, ts, SALT);

        bool rejects = ts > block.timestamp && (mode == uint48(IPermit3.PermitType.Unlock) || mode == LATER_EXPIRATION);
        if (rejects) {
            vm.expectRevert(_invalidTimestamp(ts));
        }
        permit3.permit(owner, SALT, DEADLINE, ts, cp.permits, sig);

        (,, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertLe(storedTs, block.timestamp);
    }

    // ---- the last representable second (no code change; recorded for the boundary) ----

    /// At block.timestamp == type(uint48).max a Lock signed with that timestamp is not in the future and is stored
    function test_lockAtUint48MaxBlockTimeStoresMax() public {
        vm.warp(type(uint48).max);
        uint48 maxTs = type(uint48).max; // also the only deadline that has not expired

        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        bytes memory sig = _signPermit(cp, maxTs, maxTs, SALT);
        permit3.permit(owner, SALT, maxTs, maxTs, cp.permits, sig);

        (, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2);
        assertEq(storedTs, maxTs);
    }

    /// Past type(uint48).max the unsigned path truncates block.timestamp: the stored value wraps down, never up
    function test_pastUint48MaxUnsignedPathWrapsDownward() public {
        vm.warp(uint256(type(uint48).max) + 2); // 2^48 + 1

        IPermit3.ChainPermits memory cp = _one(uint48(IPermit3.PermitType.Lock), 0);
        vm.prank(owner);
        permit3.permit(cp.permits);

        (, uint48 expiration, uint48 storedTs) = permit3.allowance(owner, address(token), spender);
        assertEq(expiration, 2);
        assertEq(storedTs, 1, "uint48(block.timestamp) wrapped to 1");
    }
}
