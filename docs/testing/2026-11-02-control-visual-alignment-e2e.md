# Cross-surface control visual alignment device E2E

Date: 2026-11-02

Status: implementation may proceed offline. The connected phone is explicitly
unavailable until the user says otherwise; every row is `Pending`.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| CVA-01 | Launch and onboarding | Page inset, primary actions, inputs, option rows and headings align to the same edges without oversized controls | Pending |
| CVA-02 | Conversation header and drawer | Back/menu, title, utility icon and drawer rows share the same hit target, icon and baseline recipes | Pending |
| CVA-03 | Composer and bottom dock | Model, image, file, send, stop, queue and attachment controls use aligned sizes and gaps | Pending |
| CVA-04 | Plan and live-change surfaces | The task-plan disclosure header is 32 vp tall; progress, status chips and file-change rows form one compact hierarchy without clipping | Pending |
| CVA-05 | Pending interactions | Approval, question, option, pagination and submit controls align in dark and light themes | Pending |
| CVA-06 | Settings root and children | Header, list rows, fields, toggles, retry and destructive actions align across every page | Pending |
| CVA-07 | About and storage | Author/repository rows, storage metric and clear-cache action use documented roles | Pending |
| CVA-08 | File browser | Breadcrumbs, header actions, group labels and file rows share one inset and radius system | Pending |
| CVA-09 | File preview and lightbox | Header controls, mode switch, load-more, close/download and retry states align safely | Pending |
| CVA-10 | Plugins | Search, header action, card rows, status badges, install/update and error actions align | Pending |
| CVA-11 | Automation | Search, filters, task rows, form fields, day selector and action bars align | Pending |
| CVA-12 | Structured transcript | Process rows, tool cards, media metadata and turn-change cards use one compact disclosure language | Pending |
| CVA-13 | Large text and narrow layout | No label/control overlap, unintended wrap or horizontal drift | Pending |
| CVA-14 | Dark theme | Borders, selected surfaces, chips and icon weights remain coherent | Pending |
| CVA-15 | Reduced motion and transparency | Alignment survives fallback surfaces; transitions resolve without changing final geometry | Pending |
| CVA-16 | API 23 fallback | Opaque surfaces preserve the same insets and control recipes | Pending |

## Latest offline evidence

Device execution is still prohibited. These checks validate the current working
tree only and do not prove any device row:

- PR QA run `20261101T170806Z-cc825f58`: passed.
- Targeted source and model contracts: 102/102 passed.
- Mock mapping: 10/10 screens, 34/34 states and 27/27 registered features.
- Release builds for `default`, `store` and `mock`: successful.

| Product | HAP | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | 2,093,133 | `6dcf2bd4d3c7047ad18c9d4939bb2c7fd3bdb27a095e48503875aea92c6618d1` |
| store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | 2,093,222 | `c1d1d3f5901b14cabf8440baa2d8c475d0bb335903c998aa450228c3ef320dcc` |
| mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | 2,093,190 | `36b52cbd9ba1dffabe3eda11afa3966e086ec643bbe9abf81afc3758bff65926` |

The HAP hashes identify this local build. They must be refreshed after any later
source change and cannot substitute for current screenshots, ArkUI bounds or
interaction evidence from the target device.

## Required evidence after device access returns

- Rebuild and install the current Mock HAP.
- Capture every affected screen and state.
- Inspect the composited screenshots and ArkUI bounds for edge alignment, control
  size, text overflow and inconsistent radii.
- Run the affected interaction drivers.
- Record run ID, HAP hash, device/API details and screenshot paths before marking
  any row passed.
