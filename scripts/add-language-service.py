#!/usr/bin/env python3
"""
Add LanguageDetectionService.swift to Xcode project
"""
import os
import re
import uuid

project_file = '/Users/matthanson/Heirloom/Heirloom.xcodeproj/project.pbxproj'

# Generate UUIDs for the new file references
file_ref_uuid = str(uuid.uuid4()).replace('-', '').upper()[:24]
build_file_uuid = str(uuid.uuid4()).replace('-', '').upper()[:24]

print(f"🔧 Adding LanguageDetectionService.swift to Xcode project...")
print(f"   File Reference UUID: {file_ref_uuid}")
print(f"   Build File UUID: {build_file_uuid}")

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# 1. Add PBXFileReference
file_reference = f"""		{file_ref_uuid} /* LanguageDetectionService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LanguageDetectionService.swift; sourceTree = "<group>"; }};"""

# Find the Services section and add our file reference
services_pattern = r'(/\* CloudRecipeImportService\.swift \*/.*?sourceTree = "<group>"; };)'
match = re.search(services_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + file_reference + content[insert_pos:]
    print("✅ Added PBXFileReference")
else:
    print("❌ Could not find Services section for file reference")

# 2. Add to Services group children
services_group_pattern = r'(E56D[A-F0-9]+ /\* Services \*/ = \{[^}]+children = \([^)]+)'
match = re.search(services_group_pattern, content)
if match:
    # Add our file reference UUID to the children array
    insert_pos = match.end()
    new_child = f'\n				{file_ref_uuid} /* LanguageDetectionService.swift */,'
    content = content[:insert_pos] + new_child + content[insert_pos:]
    print("✅ Added to Services group children")
else:
    print("❌ Could not find Services group")

# 3. Add PBXBuildFile
build_file = f"""		{build_file_uuid} /* LanguageDetectionService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* LanguageDetectionService.swift */; }};"""

# Find a good spot in PBXBuildFile section (near other service files)
build_file_pattern = r'(/\* CloudRecipeImportService\.swift in Sources \*/.*?};)'
match = re.search(build_file_pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + build_file + content[insert_pos:]
    print("✅ Added PBXBuildFile")
else:
    print("❌ Could not find build file section")

# 4. Add to PBXSourcesBuildPhase for Heirloom target
sources_phase_pattern = r'(E56D[A-F0-9]+ /\* Sources \*/ = \{[^}]+files = \([^)]+)'
matches = list(re.finditer(sources_phase_pattern, content))
if matches:
    # Add to first Sources build phase (main target)
    match = matches[0]
    insert_pos = match.end()
    new_source = f'\n				{build_file_uuid} /* LanguageDetectionService.swift in Sources */,'
    content = content[:insert_pos] + new_source + content[insert_pos:]
    print("✅ Added to Sources build phase")
else:
    print("❌ Could not find Sources build phase")

# Write back to file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully added LanguageDetectionService.swift to Xcode project!")
print("   You may need to close and reopen Xcode for changes to take effect.")
