# Attachments JSON Scope Fix

## Problem

LSL compile error at line 876, column 29:
```
Name not defined within scope
```

The error occurred because the variable `attachments_json` was declared inside conditional blocks but used outside them.

## Root Cause

In the `processWaypoint()` function, `attachments_json` was declared with the `string` type inside each conditional block:

```lsl
if (llGetListLength(configData) > 0)
{
    // ...
    string attachments_json = llList2String(configData, 5);  // Declared in this block
}
else if (wpDesc != "")
{
    // ...
    string attachments_json = llList2String(wpData, 5);  // Declared in this block
}
else
{
    // ...
    string attachments_json = "";  // Declared in this block
}

// Later in the function...
if (attachments_json != "")  // ERROR: Variable not in scope!
{
    llMessageLinked(LINK_SET, 0, "ATTACHMENTS:" + attachments_json, NULL_KEY);
}
```

In LSL (like most programming languages), variables declared inside a block only exist within that block's scope. Once the block ends, the variable is no longer accessible.

## Solution

Declare `attachments_json` once before the conditional blocks, then assign values inside each block:

```lsl
// Declare attachments_json outside conditional blocks for proper scope
string attachments_json = "";

if (llGetListLength(configData) > 0)
{
    // ...
    attachments_json = llList2String(configData, 5);  // Assignment only
}
else if (wpDesc != "")
{
    // ...
    attachments_json = llList2String(wpData, 5);  // Assignment only
}
else
{
    // ...
    attachments_json = "";  // Assignment only
}

// Later in the function...
if (attachments_json != "")  // OK: Variable is in scope!
{
    llMessageLinked(LINK_SET, 0, "ATTACHMENTS:" + attachments_json, NULL_KEY);
}
```

## Changes Made

**File:** `RoseReceptionist.LSL/RoseReceptionist_GoWander3.lsl`

1. Added declaration of `attachments_json` at line 801 (before conditional blocks)
2. Changed lines 812, 823, 833 from `string attachments_json = ...` to `attachments_json = ...`

## Impact

- **Lines changed:** 4 lines modified, 1 line added
- **Functional impact:** None - the variable behavior is identical, only the scope is corrected
- **Compilation:** Error resolved, script should now compile successfully

## Testing

The fix should be verified by:
1. Compiling the script - should compile without errors
2. Testing waypoint navigation with attachments configured
3. Verifying that the `ATTACHMENTS:` message is properly sent when attachments are configured

## Related

This fix is part of the broader stack-heap collision fixes in the GoWander3 script. The scope error was discovered during compilation after the previous optimizations were applied.
