# Composer IME layout stability

Date: 2026-11-02

## User outcome

When the user taps or focuses the conversation composer and the soft keyboard
opens, the app must not translate the whole screen upward. The conversation
header and its controls must remain at the same screen position; only the
transcript viewport and composer should adapt to the reduced height.

## Required behavior

- Native conversation pages use ArkUI keyboard avoidance mode `RESIZE`.
- Web compatibility pages retain their existing page avoidance behavior.
- Keyboard avoidance is applied during the first native page appearance even
  when the persisted mode is already `native` and no mode-change watcher fires.
- The header, title, plan/subagent controls and safe-area top inset remain fixed
  relative to the screen while the IME is visible.
- The transcript top remains stable and its viewport height decreases enough for
  the composer to remain above the IME.
- The normal page bottom inset is 20vp. While the IME is visible, the composer
  uses a tighter 12vp gap so it sits closer to the keyboard.
- Dismissing the IME restores the previous header, transcript and composer
  geometry and preserves the draft.
- A failed or unavailable keyboard transition must not be replaced with a fixed
  bottom padding or a manual page `translate`.

## Acceptance

Device evidence must compare the header and composer bounds before and while
the IME is open. It must cover dark and light themes, an entered draft, close
and reopen, and the restored composer position. A static screenshot, a source
contract or a Mock-only capture is not sufficient device proof.
