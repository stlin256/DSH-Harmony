# Conversation stability during live output

Date: 2026-11-05

Long-running real conversations must not stutter or terminate the app. The
reported symptoms were frame drops during continuous output and several
app exits around midday on the 0.4.9 build.

- Keep live process/answer streaming within the existing cadence budgets.
- Never run decoding or transform tickers while the ability is backgrounded.
- Keep per-frame state updates to the smallest possible component; animated
  image resources stay isolated from the text sweep state.
- Add a repeatable stress scenario and record process liveness for a
  multi-minute continuous stream.
