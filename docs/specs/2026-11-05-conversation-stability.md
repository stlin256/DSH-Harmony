# Conversation stability changes

Date: 2026-11-05

- Remove all per-frame transform/decoding tickers from the running tail.
- Isolate the animated DSH whale in `NativeRunningWhale`; the parent sweep
  state must not rebuild it.
- Guard every tail timer with `nativeAppActive`, clear timers on disappear,
  and stop the sweep when paused.
- Keep the transcript source refresh on the existing `setTail` fast path; the
  trailing running row is a static `ListItem` outside `LazyForEach` so stream
  updates cannot reorder or remount it.
- Record the mock 3-minute liveness sample and the device fault-log access
  limitation; a real-Host crash stack is still required if crashes recur.

- Cache the authoritative running-turn start by `model.lastSeq()` and running
  state instead of scanning `messages` from build on every frame.
- Keep the 6-minute continuous-render stress sample as the current liveness
  evidence; a real-Host crash reproduction is still required to prove the
  crash fix.
