# Share Extension & Unified Video Import Testing Guide

## Setup
- Build on physical device (Share Extension requires device)
- Verify both targets signed with same team
- Verify App Group configured in both targets

## Manual Test Matrix

### Share Extension - Video Files
| Source | Action | Expected |
|--------|--------|----------|
| Photos - regular video | Share → Heirloom | Saves video, opens app |
| Screen recording (TikTok) | Share → Heirloom | Watermark detected |
| Screen recording (Instagram) | Share → Heirloom | Watermark detected |
| Files app video | Share → Heirloom | Import succeeds |

### Share Extension - URLs
| Platform | URL Type | Expected |
|----------|----------|----------|
| TikTok | Full URL | Metadata fetched, prompts for video |
| TikTok | vm.tiktok.com short | URL expanded, metadata fetched |
| Instagram | Reel URL | Metadata attempted |
| YouTube | Full/Short URL | Metadata fetched |

### Three-Tier Extraction Cascade
| Video Type | Expected Tier | Verify |
|------------|---------------|--------|
| Clear recipe narration | Audio Transcript | Fastest, cheapest |
| Music + text overlays | On-Screen Text | OCR used |
| ASMR/silent + no text | Visual Frames | Most expensive |
| Talking but non-recipe | On-Screen Text (fallback) | Tries OCR before visual |

### Paywall Triggers
| Scenario | Expected |
|----------|----------|
| Audio extraction succeeds | Free - no paywall |
| OCR extraction succeeds | Free - no paywall |
| Both audio + OCR fail, not premium | Show paywall for visual extraction |
| Both audio + OCR fail, premium user | Proceed with visual extraction |
| URL import (non-premium) | Show hard paywall |

### Attribution Detection
| Scenario | Expected |
|----------|----------|
| Video with TikTok watermark | @username detected |
| URL shared from TikTok | Creator from oembed |
| Clean video (no watermark) | No detection, manual option |

## Performance Benchmarks
- Share Extension launch: < 1s
- Audio analysis: < 10s
- OCR analysis: < 15s
- Watermark detection: < 5s

## Known Limitations
- Share Extension cannot download videos from URLs directly (platform restrictions)
- Instagram oembed API frequently blocks requests
- Watermark detection requires visible @username in corners
- Short URLs may require network to expand before processing
