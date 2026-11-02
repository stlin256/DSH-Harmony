# Upstream DSH protocol fixtures

This directory is the fixture location pinned by `protocol.lock.json`.

The gateway tests keep deterministic, synthetic protocol traces inline so that
no real transcript content is committed. Any future fixture copied from the
pinned upstream revision must be reduced to synthetic data and must preserve the
wire protocol version recorded in the lock file.
