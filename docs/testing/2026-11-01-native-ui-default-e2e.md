# Native UI startup E2E

Date: 2026-11-01

Status: implementation complete; the primary native cold-start rows pass on the
physical phone. The remaining migration and authentication rows still require
isolated fixtures.

| ID | Scenario | Expected result | Result |
|---|---|---|---|
| NUI-01 | Inspect the installed application package | Community Release metadata is visible and matches the newly installed HAP | Pass: installed community Release `0.4.7` (`versionCode 28`); HDC reports `debug: false` |
| NUI-02 | Cold-start an affected installation with no `uiMode` preference | Native workspace opens after authentication; no compatibility page is the initial surface | Pass: HDC force-stop plus cold launch restored the native conversation surface |
| NUI-03 | Cold-start a fresh-install fixture | Native workspace is selected by default | Pending |
| NUI-04 | Open application settings | No compatibility mode control is visible | Pending |
| NUI-05 | Terminate and reopen with native selected | Native workspace remains selected | Pass: cold launch returned directly to the native conversation UI |
| NUI-06 | Upgrade an installation containing a legacy compatibility value | It migrates once to native without losing the saved service, login mode or caches | Pending |
| NUI-07 | Complete Passkey or native-key authentication | Authentication still succeeds while the normal product surface remains native | Pending |

Device evidence must be captured through HDC. A result is not Pass until the
installed bundle and the visible startup surface have both been checked.

