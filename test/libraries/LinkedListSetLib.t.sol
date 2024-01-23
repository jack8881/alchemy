// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import {SetValue, SENTINEL_VALUE} from "../../src/libraries/Constants.sol";
import {LinkedListSet, LinkedListSetLib} from "../../src/libraries/LinkedListSetLib.sol";

// Ported over from test/AssociatedLinkedListSetLib.t.sol, dropping test_no_address_collision
contract LinkedListSetLibTest is Test {
    using LinkedListSetLib for LinkedListSet;

    LinkedListSet internal _set;

    // User-defined function for wrapping from bytes30 (uint240) to SetValue
    // Can define a custom one for addresses, uints, etc.
    function _getListValue(uint240 value) internal pure returns (SetValue) {
        return SetValue.wrap(bytes30(value));
    }

    // A lot of these tests were auto-generated by copilot and manually inspected.
    // In addition to these tests, there are also invariant tests in
    // test/invariant/LinkedListSetLibInvariants.t.sol

    function test_add_contains() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));
    }

    function test_empty() public {
        SetValue value = _getListValue(12);
        assertFalse(_set.contains(value));
        assertTrue(_set.isEmpty());
    }

    function test_remove() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        assertTrue(_set.tryRemove(value));
        assertFalse(_set.contains(value));
    }

    function test_remove_empty() public {
        SetValue value = _getListValue(12);
        assertFalse(_set.tryRemove(value));
    }

    function test_remove_nonexistent() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        SetValue value2 = _getListValue(13);
        assertFalse(_set.tryRemove(value2));
        assertTrue(_set.contains(value));
    }

    function test_remove_nonexistent_empty() public {
        SetValue value = _getListValue(12);
        assertFalse(_set.tryRemove(value));
    }

    function test_remove_nonexistent_empty2() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        SetValue value2 = _getListValue(13);
        assertFalse(_set.tryRemove(value2));
        assertTrue(_set.contains(value));
    }

    function test_add_remove_add() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        assertTrue(_set.tryRemove(value));
        assertFalse(_set.contains(value));

        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));
    }

    function test_add_remove_add_empty() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        assertTrue(_set.tryRemove(value));
        assertFalse(_set.contains(value));

        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));
    }

    function test_clear() public {
        SetValue value = _getListValue(12);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        _set.clear();

        assertFalse(_set.contains(value));
        assertTrue(_set.isEmpty());
    }

    function test_getAll() public {
        SetValue value = _getListValue(12);
        SetValue value2 = _getListValue(13);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.tryAdd(value2));

        SetValue[] memory values = _set.getAll();
        assertEq(values.length, 2);
        // Returned set will be in reverse order of added elements
        assertEq(SetValue.unwrap(values[1]), SetValue.unwrap(value));
        assertEq(SetValue.unwrap(values[0]), SetValue.unwrap(value2));
    }

    function test_getAll2() public {
        SetValue value = _getListValue(12);
        SetValue value2 = _getListValue(13);
        SetValue value3 = _getListValue(14);
        assertTrue(_set.tryAdd(value));
        assertTrue(_set.tryAdd(value2));
        assertTrue(_set.tryAdd(value3));

        SetValue[] memory values = _set.getAll();
        assertEq(values.length, 3);
        // Returned set will be in reverse order of added elements
        assertEq(SetValue.unwrap(values[2]), SetValue.unwrap(value));
        assertEq(SetValue.unwrap(values[1]), SetValue.unwrap(value2));
        assertEq(SetValue.unwrap(values[0]), SetValue.unwrap(value3));
    }

    function test_getAll_empty() public {
        SetValue[] memory values = _set.getAll();
        assertEq(values.length, 0);
    }

    function test_tryRemoveKnown1() public {
        SetValue value = _getListValue(12);

        assertTrue(_set.tryAdd(value));
        assertTrue(_set.contains(value));

        assertTrue(_set.tryRemoveKnown(value, SENTINEL_VALUE));
        assertFalse(_set.contains(value));
        assertTrue(_set.isEmpty());
    }

    function test_tryRemoveKnown2() public {
        SetValue value1 = _getListValue(12);
        SetValue value2 = _getListValue(13);

        assertTrue(_set.tryAdd(value1));
        assertTrue(_set.tryAdd(value2));
        assertTrue(_set.contains(value1));
        assertTrue(_set.contains(value2));

        // Assert that getAll returns the correct values
        SetValue[] memory values = _set.getAll();
        assertEq(values.length, 2);
        assertEq(SetValue.unwrap(values[1]), SetValue.unwrap(value1));
        assertEq(SetValue.unwrap(values[0]), SetValue.unwrap(value2));

        assertTrue(_set.tryRemoveKnown(value1, bytes32(SetValue.unwrap(value2))));
        assertFalse(_set.contains(value1));
        assertTrue(_set.contains(value2));

        // Assert that getAll returns the correct values
        values = _set.getAll();
        assertEq(values.length, 1);
        assertEq(SetValue.unwrap(values[0]), SetValue.unwrap(value2));

        assertTrue(_set.tryRemoveKnown(value2, SENTINEL_VALUE));
        assertFalse(_set.contains(value1));

        assertTrue(_set.isEmpty());
    }

    function test_tryRemoveKnown_invalid1() public {
        SetValue value1 = _getListValue(12);
        SetValue value2 = _getListValue(13);

        assertTrue(_set.tryAdd(value1));
        assertTrue(_set.tryAdd(value2));

        assertFalse(_set.tryRemoveKnown(value1, bytes32(SetValue.unwrap(value1))));
        assertTrue(_set.contains(value1));

        assertFalse(_set.tryRemoveKnown(value2, bytes32(SetValue.unwrap(value2))));
        assertTrue(_set.contains(value2));
    }

    function test_isSentinel() public {
        bytes32 val1 = bytes32(uint256(0));
        assertFalse(LinkedListSetLib.isSentinel(val1));

        bytes32 val2 = bytes32(uint256(1));
        assertTrue(LinkedListSetLib.isSentinel(val2));

        bytes32 val3 = bytes32(uint256(3));
        assertTrue(LinkedListSetLib.isSentinel(val3));

        bytes32 val4 = bytes32(uint256(2));
        assertFalse(LinkedListSetLib.isSentinel(val4));
    }

    function test_userFlags_fail_does_not_contain() public {
        SetValue value1 = _getListValue(12);
        SetValue value2 = _getListValue(13);

        assertTrue(_set.tryAdd(value1));
        assertTrue(_set.tryAdd(value2));

        assertFalse(_set.trySetFlags(_getListValue(14), uint8(0xF0)));
    }

    function test_userFlags_basic() public {
        SetValue value1 = _getListValue(12);
        SetValue value2 = _getListValue(13);

        assertTrue(_set.tryAdd(value1));
        assertTrue(_set.tryAdd(value2));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));
        assertTrue(_set.trySetFlags(value2, uint8(0x0C)));

        assertEq(_set.getFlags(value1), uint8(0xF0));
        assertEq(_set.getFlags(value2), uint8(0x0C));
    }

    function test_userFlags_getAll() public {
        SetValue value1 = _getListValue(12);
        SetValue value2 = _getListValue(13);

        assertTrue(_set.tryAdd(value1));
        assertTrue(_set.tryAdd(value2));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));
        assertTrue(_set.trySetFlags(value2, uint8(0x0C)));

        SetValue[] memory values = _set.getAll();
        assertEq(values.length, 2);
        assertEq(SetValue.unwrap(values[0]), SetValue.unwrap(value2));
        assertEq(SetValue.unwrap(values[1]), SetValue.unwrap(value1));

        assertEq(_set.getFlags(values[0]), uint8(0x0C));
        assertEq(_set.getFlags(values[1]), uint8(0xF0));
    }

    function test_userFlags_tryEnable() public {
        SetValue value1 = _getListValue(12);

        assertTrue(_set.tryAdd(value1));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));
        assertTrue(_set.tryEnableFlags(value1, uint8(0x0C)));

        assertEq(_set.getFlags(value1), uint8(0xFC));
    }

    function test_userFlags_tryDisable() public {
        SetValue value1 = _getListValue(12);

        assertTrue(_set.tryAdd(value1));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));
        assertTrue(_set.tryDisableFlags(value1, uint8(0xC0)));

        assertEq(_set.getFlags(value1), uint8(0x30));
    }

    function test_userFlags_flagsEnabled() public {
        SetValue value1 = _getListValue(12);

        assertTrue(_set.tryAdd(value1));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));

        assertTrue(_set.flagsEnabled(value1, uint8(0x80)));
        assertTrue(_set.flagsEnabled(value1, uint8(0xC0)));
        assertFalse(_set.flagsEnabled(value1, uint8(0x0C)));
    }

    function test_userFlags_flagsDisabled() public {
        SetValue value1 = _getListValue(12);

        assertTrue(_set.tryAdd(value1));

        assertTrue(_set.trySetFlags(value1, uint8(0xF0)));

        assertFalse(_set.flagsDisabled(value1, uint8(0x80)));
        assertFalse(_set.flagsDisabled(value1, uint8(0xC0)));
        assertTrue(_set.flagsDisabled(value1, uint8(0x0C)));
    }
}
