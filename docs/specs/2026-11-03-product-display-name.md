# Product Display Name Specification

Date: 2026-11-03

## Product Contract

Each target owns one field:

```ts
static readonly appDisplayName: string = 'DSH Harmony';
```

The store target uses `DSH Mobile`; default and Mock keep `DSH Harmony`. The
field is the only product display-name input. Bundle names, repository URLs,
package names and release artifact names remain technical identity and are not
derived from this field.

`BuildInfo.appName` is:

```ts
ProductCapabilities.appDisplayName
```

`BuildInfo.appFilePrefix` is a filesystem-safe derivative used for image-save
titles.

## Native Consumers

The following surfaces consume `BuildInfo.appName` instead of a literal:

- first-launch welcome, iteration notice and plugin-install guide;
- the first-level workspace/sidebar header;
- About settings;
- native notification test copy and connection fallback title;
- Quick and Overview service cards;
- image-save title;
- Mock disclosure and showcase fixture labels.

Internal repository links and technical log labels may retain `DSH-Harmony`
where the repository or package identity is being named.

## Launcher Synchronization

`AppScope/resources/base/element/string.json` remains the source launcher label
with `app_name = DSH Harmony`. `scripts/build-harmony.ps1` reads the selected
target's `ProductCapabilities.ets`, updates only the `app_name` resource value
before the Hvigor/DevEco build, and restores the original bytes in `finally`.

The store build therefore has `DSH Mobile` in both the launcher label and all
native runtime surfaces. Direct IDE builds should use the product build script
when the launcher name must be variant-specific.

## Verification

- Add the product display-name contract to
  `scripts/verify-harmony-product-variants.mjs`.
- Add service/source assertions to
  `gateway/test/native-models.test.mjs`.
- Build default, store and Mock Release artifacts.
- Inspect the store HAP's launcher resource and native copy.
- Add the device table in
  [`2026-11-03-product-display-name-e2e.md`](../testing/2026-11-03-product-display-name-e2e.md).
