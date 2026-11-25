# Scanner app UX research (November 2026)

What the leading scanner apps do well, and what ArmScan takes from each.
ArmScan borrows patterns, not branding, artwork or exact layouts.

| App | What reviewers praise | What reviewers criticise |
|---|---|---|
| Adobe Scan | Easy to use, strong OCR, tight PDF workflow (Acrobat, Fill & Sign) | Upsell to subscription; best features tied to Adobe account |
| Genius Scan | Smart page detection, fast, works offline, batch scanning, encryption | Cloud sync and integrations behind paid tiers |
| CamScanner | Business features: cloud upload, team sharing | Limited free tier, past privacy concerns |
| Apple Notes / Files scanner | "Surprisingly good scans", instant, free, auto-capture | Few export or organisation options |
| Google Drive scanner (ML Kit) | Simple and reliable | Tied to Drive |
| Microsoft Lens | Was the go-to free, ad-free scanner with OneDrive export | **Retired**: pulled from stores 9 Feb 2026, scanning stopped 9 Mar 2026. Replacement is the OneDrive app's scanner, which can't save scans locally |
| Ad-supported scanners (TapScanner, Tiny Scanner…) | Free | Ads, watermarks, subscription prompts |

Sources: TechRadar "Best document scanning app" (Nov 2025), 9meters "Best Mobile Scanning Apps (2026)",
Microsoft Support "Retirement of Microsoft Lens", Windows Central (Feb 2026).

## Principles ArmScan adopts

1. **One tap to scan.** The primary button is always visible at the bottom of the home screen, in thumb reach. Camera opens straight into scanning (Apple Notes, Lens).
2. **Native auto-capture.** Live edge detection, automatic shutter when the page is steady, perspective correction and filters come from the OS engines (VisionKit on iOS, ML Kit on Android): the fastest and most accurate option, with zero custom camera code to maintain.
3. **Multipage by default.** Keep scanning page after page in one session; add, delete and drag-to-reorder pages afterwards (Genius Scan).
4. **OCR happens quietly in the background**, on device, and makes every PDF searchable (invisible text layer) and every scan searchable from the home screen (Adobe Scan).
5. **Local first, cloud on request.** Everything is saved on the phone. OneDrive is one tap or automatic, never required. This fills the gap Lens left: OneDrive export *and* local saving.
6. **No ads, no watermarks, no forced sign-in.** These are the top complaints about free scanners.
7. **Smart default names** ("Scan 2026-11-25 14.51"), tap the title to rename.
8. **Calm, professional visual style:** white and slate neutrals, one blue for actions, system fonts, large 48dp+ touch targets, light and dark mode.
