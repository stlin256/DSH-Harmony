# Login Error Motion

Date opened: 2026-11-03

Status: implementation in progress

## User Requirement

- `LOGIN-ERR-REQ-01` Login errors must not pop into the interface without motion.
- `LOGIN-ERR-REQ-02` Inline authentication errors and the full connection-error
  card use one quiet, interruptible appearance transition.
- `LOGIN-ERR-REQ-03` Clearing or replacing an error follows the same motion
  language and never uses a decorative shake or looping attention cue.
- `LOGIN-ERR-REQ-04` Reduced motion resolves every error-state change directly
  to its final state.

## Constraints

- Reuse the semantic `micro` motion token and the shared row transition.
- Do not move the logo, page header or hardware safe-area geometry.
- The error must remain readable, copyable and fully inside the viewport while
  it enters or exits.

## Acceptance

- Source/model tests prove login error state changes use `NativeMotion` and both
  error surfaces own a transition.
- A current Mock HAP device run opens the login form, submits an invalid empty
  address, and captures the settled inline error with stable layout bounds.
- The same interaction under reduced motion renders the final error without an
  intermediate animation state.
