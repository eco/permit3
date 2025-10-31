// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title RecursiveTypeTester
 * @notice Test harness to systematically test where Solidity's recursive type constraints break
 * @dev Tests incremental complexity to find if fixed-size arrays bypass Error 4103
 */
contract RecursiveTypeTester {
    // ============================================
    // LEVEL 0: Baseline - Simple Non-Recursive
    // ============================================

    struct Simple {
        uint256 value;
    }

    function testSimple(Simple memory s) external pure returns (uint256) {
        return s.value;
    }

    // ============================================
    // LEVEL 1: Dynamic Array of Primitives
    // ============================================

    struct WithDynamicPrimitives {
        uint256[] values;
    }

    function testDynamicPrimitives(WithDynamicPrimitives memory s) external pure returns (uint256) {
        return s.values.length > 0 ? s.values[0] : 0;
    }

    // ============================================
    // LEVEL 2: Fixed Array of Structs (Non-Recursive)
    // ============================================

    struct Inner {
        uint256 x;
    }

    struct WithFixedStructArray {
        Inner[1] inners;
    }

    function testFixedStructArray(WithFixedStructArray memory s) external pure returns (uint256) {
        return s.inners[0].x;
    }

    struct WithFixedStructArray3 {
        Inner[3] inners;
    }

    function testFixedStructArray3(WithFixedStructArray3 memory s) external pure returns (uint256) {
        return s.inners[0].x;
    }

    // ============================================
    // LEVEL 3: CONTROL - Dynamic Recursive Array
    // Expected: Error 4103 - Recursive type not allowed
    // Result: ❌ FAILED - Error 4103 (confirmed)
    // ============================================

    // struct RecursiveDynamic {
    //     uint256 value;
    //     RecursiveDynamic[] children;  // Dynamic array - triggers Error 4103
    // }

    // function testRecursiveDynamic(RecursiveDynamic memory s) external pure returns (uint256) {
    //     return s.value;
    // }

    // ============================================
    // LEVEL 4: HYPOTHESIS - Fixed Recursive Array
    // Expected: Will this bypass Error 4103?
    // Result: ❌ FAILED - Error 2046 "Recursive struct definition"
    // Conclusion: Even fixed-size arrays don't allow direct recursion
    // ============================================

    // struct RecursiveFixed {
    //     uint256 value;
    //     RecursiveFixed[1] children;  // Fails with Error 2046
    // }

    // function testRecursiveFixed(RecursiveFixed memory s) external pure returns (uint256) {
    //     return s.value;
    // }

    // ============================================
    // LEVEL 5: Indirect Recursion with Fixed Arrays
    // Test: Can we use fixed arrays for INDIRECT recursion?
    // Pattern: MockStruct → MockChunk[1] → MockStruct[1]
    // Result: ❌ FAILED - Error 2046 "Recursive struct definition"
    // Conclusion: Fixed arrays don't bypass recursion constraints for indirect recursion either
    // ============================================

    // struct MockStruct {
    //     bytes32 typeHash;
    //     MockChunk[1] chunks;  // Fixed size - still triggers Error 2046
    // }

    // struct MockChunk {
    //     uint256[] primitives;
    //     MockStruct[1] structs;  // Fixed size - still circular reference
    // }

    // function testMockTypedEncoder(MockStruct memory s) external pure returns (bytes32) {
    //     return s.typeHash;
    // }
}

/**
 * FINDINGS SUMMARY
 * ================
 *
 * Level 0-2: ✅ PASSED - Non-recursive structures work fine in external functions
 *   - Simple structs
 *   - Dynamic arrays of primitives
 *   - Fixed arrays of non-recursive structs
 *
 * Level 3: ❌ FAILED - Error 4103: "Recursive type not allowed for public or external contract functions"
 *   - Direct recursion with dynamic arrays: `struct A { A[] children; }`
 *   - This is the expected error for recursive types in external functions
 *
 * Level 4: ❌ FAILED - Error 2046: "Recursive struct definition"
 *   - Direct recursion with fixed arrays: `struct A { A[1] children; }`
 *   - Fails even EARLIER than Level 3 - can't even define such a struct
 *   - Fixed arrays do NOT bypass recursion constraints
 *
 * Level 5: ❌ FAILED - Error 2046: "Recursive struct definition"
 *   - Indirect recursion with fixed arrays: `struct A { B[1] b; } struct B { A[1] a; }`
 *   - Solidity detects circular references even through intermediate types
 *   - Fixed arrays do NOT bypass indirect recursion constraints
 *
 * CONCLUSION
 * ==========
 *
 * The hypothesis that fixed-size arrays bypass Solidity's recursive type constraints is FALSE.
 *
 * Key Insights:
 * 1. Error 2046 (struct definition level) is triggered by fixed-size arrays with direct recursion
 * 2. Error 2046 is also triggered by fixed-size arrays with indirect recursion
 * 3. Error 4103 (function parameter level) is triggered by dynamic arrays in external functions
 * 4. Solidity's compiler thoroughly analyzes struct dependencies regardless of array type
 *
 * Implications for TypedEncoder:
 * - Cannot use fixed-size arrays to enable external function parameters
 * - TypedEncoder.Struct MUST remain internal-only or use bytes encoding workaround
 * - The current test failure (22 tests with vm.expectRevert) is due to library call depth,
 *   NOT a solvable problem with array type changes
 */
