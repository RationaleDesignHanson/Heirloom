# Fix Log — Source Attribution Registry

**Branch:** `feature/source-attribution-registry`

## Issues

| # | Date | Test | Symptom | Root Cause | Fix | Status |
|---|------|------|---------|------------|-----|--------|
| 1 | 2026-02-07 | A1 | `Cannot find type 'KnownSource' in scope` — build fails with 27 errors | 4 new files (KnownSource.swift, SchemaV3.swift, SourceAttributionService.swift, SourceAttributionMigration.swift) not added to Xcode target | Added PBXBuildFile, PBXFileReference, PBXGroup, and PBXSourcesBuildPhase entries to project.pbxproj. Created Attribution group with `path = Attribution` for subdirectory file. | fixed |
| 2 | 2026-02-07 | A1 | `switch must be exhaustive` in SocialMetadataService.swift:42 | `.pinterest` case added to `SocialPlatform` enum but not handled in switch | Added `case .pinterest` alongside `.unknown` to use `fetchGenericMetadata` | fixed |
| 3 | 2026-02-07 | A1 | `switch must be exhaustive` in CreatorAttributionBadge.swift:29 | `.pinterest` case added to `SocialPlatform` enum but not handled in platformColor switch | Added `case .pinterest: return .orange` | fixed |

## Status Key

- **open** — Issue identified, not yet fixed
- **fixed** — Fix applied and verified
- **wontfix** — Accepted behavior, documented reason below

## Notes

```
```
