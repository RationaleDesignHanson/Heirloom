#!/usr/bin/env python3
"""
Complete adding LanguageDetectionService.swift to Xcode project
Adds file to Services group children and Sources build phase
"""
import re

project_file = '/Users/matthanson/Heirloom/Heirloom.xcodeproj/project.pbxproj'

# UUIDs from previous script run
file_ref_uuid = 'D0D8A34356274E14A362177A'
build_file_uuid = '1BAA4B71E9134A38B8F2EC28'

print(f"🔧 Completing LanguageDetectionService.swift integration...")
print(f"   File Reference UUID: {file_ref_uuid}")
print(f"   Build File UUID: {build_file_uuid}")

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# 1. Add to Services group children (after CloudRecipeImportService)
services_pattern = r'(\t\t\t\t1C130EE6834B5AABCC4B67EF /\* CloudRecipeImportService\.swift \*/,)'
match = re.search(services_pattern, content)
if match:
    insert_pos = match.end()
    new_child = f'\n\t\t\t\t{file_ref_uuid} /* LanguageDetectionService.swift */,'
    content = content[:insert_pos] + new_child + content[insert_pos:]
    print("✅ Added to Services group children")
else:
    print("❌ Could not find Services group - may already be added")

# 2. Add to PBXSourcesBuildPhase (after CloudRecipeImportService)
sources_pattern = r'(\t\t\t\t73CD8315C072A52F2AAEBB5C /\* CloudRecipeImportService\.swift in Sources \*/,)'
match = re.search(sources_pattern, content)
if match:
    insert_pos = match.end()
    new_source = f'\n\t\t\t\t{build_file_uuid} /* LanguageDetectionService.swift in Sources */,'
    content = content[:insert_pos] + new_source + content[insert_pos:]
    print("✅ Added to Sources build phase")
else:
    print("❌ Could not find Sources build phase - may already be added")

# Write back to file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully completed LanguageDetectionService.swift integration!")
print("   Close and reopen Xcode for changes to take effect.")
