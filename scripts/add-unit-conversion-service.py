#!/usr/bin/env python3
"""
Add UnitConversionService.swift to Xcode project
"""
import os
import re
import uuid

project_file = '/Users/matthanson/Heirloom/Heirloom.xcodeproj/project.pbxproj'

# Generate UUIDs for the new file references
file_ref_uuid = str(uuid.uuid4()).replace('-', '').upper()[:24]
build_file_uuid = str(uuid.uuid4()).replace('-', '').upper()[:24]

print(f"🔧 Adding UnitConversionService.swift to Xcode project...")
print(f"   File Reference UUID: {file_ref_uuid}")
print(f"   Build File UUID: {build_file_uuid}")

# Read the project file
with open(project_file, 'r') as f:
    content = f.read()

# 1. Add PBXFileReference (after LanguageDetectionService)
file_reference = f"""\t\t{file_ref_uuid} /* UnitConversionService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UnitConversionService.swift; sourceTree = \"<group>\"; }};"""

services_file_pattern = r'(D0D8A34356274E14A362177A /\* LanguageDetectionService\.swift \*/.*?sourceTree = \"<group>\"; };)'
match = re.search(services_file_pattern, content, re.DOTALL)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + file_reference + content[insert_pos:]
    print("✅ Added PBXFileReference")
else:
    print("❌ Could not find LanguageDetectionService file reference")

# 2. Add to Services group children (after LanguageDetectionService)
services_group_pattern = r'(\t\t\t\tD0D8A34356274E14A362177A /\* LanguageDetectionService\.swift \*/,)'
match = re.search(services_group_pattern, content)
if match:
    insert_pos = match.end()
    new_child = f'\n\t\t\t\t{file_ref_uuid} /* UnitConversionService.swift */,'
    content = content[:insert_pos] + new_child + content[insert_pos:]
    print("✅ Added to Services group children")
else:
    print("❌ Could not find Services group")

# 3. Add PBXBuildFile (after LanguageDetectionService)
build_file = f"""\t\t{build_file_uuid} /* UnitConversionService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* UnitConversionService.swift */; }};"""

build_file_pattern = r'(1BAA4B71E9134A38B8F2EC28 /\* LanguageDetectionService\.swift in Sources \*/.*?};)'
match = re.search(build_file_pattern, content, re.DOTALL)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + build_file + content[insert_pos:]
    print("✅ Added PBXBuildFile")
else:
    print("❌ Could not find build file section")

# 4. Add to PBXSourcesBuildPhase (after LanguageDetectionService)
sources_pattern = r'(\t\t\t\t1BAA4B71E9134A38B8F2EC28 /\* LanguageDetectionService\.swift in Sources \*/,)'
match = re.search(sources_pattern, content)
if match:
    insert_pos = match.end()
    new_source = f'\n\t\t\t\t{build_file_uuid} /* UnitConversionService.swift in Sources */,'
    content = content[:insert_pos] + new_source + content[insert_pos:]
    print("✅ Added to Sources build phase")
else:
    print("❌ Could not find Sources build phase")

# Write back to file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Successfully added UnitConversionService.swift to Xcode project!")
print(f"   File Reference: {file_ref_uuid}")
print(f"   Build File: {build_file_uuid}")
