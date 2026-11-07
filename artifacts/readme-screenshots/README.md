# DSH Harmony README artwork

These are the promotional sheets referenced by `README.md` and
`README.en.md`. They are rendered from the same deterministic Mock fixtures as
`artifacts/store-screenshots`, with the community product name instead of the
store name:

```powershell
.\scripts\capture-store-screenshots.ps1 -Device '<device-id>' `
  -OutputDir artifacts/readme-screenshots -Brand 'DSH Harmony'
```

- `final/appgallery-landscape`: ten curated 1920x1080 PNGs
- `final/appgallery-portrait`: ten curated 1080x1920 PNGs
- `final`: the complete 28-image set, including unframed derivatives
- `raw`: real-device source captures

Only the brand name and in-app display name differ from the AppGallery set; the
Mock content, captions and taglines must stay identical between the two.
