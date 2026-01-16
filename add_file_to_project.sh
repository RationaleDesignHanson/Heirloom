#!/bin/bash

# Script to add HeritageRecipeCache.swift to Xcode project

PROJECT_FILE="Heirloom.xcodeproj/project.pbxproj"
FILE_NAME="HeritageRecipeCache.swift"
FILE_PATH="Heirloom/Core/Services/Heritage/$FILE_NAME"

# Generate UUIDs (using md5 hash for deterministic IDs)
FILE_REF_UUID=$(echo "FileRef_$FILE_NAME" | md5 | cut -c1-24 | tr 'a-f' 'A-F')
BUILD_FILE_UUID=$(echo "BuildFile_$FILE_NAME" | md5 | cut -c1-24 | tr 'a-f' 'A-F')

echo "Adding $FILE_NAME to Xcode project..."
echo "FileRef UUID: $FILE_REF_UUID"
echo "BuildFile UUID: $BUILD_FILE_UUID"

# Backup original project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# 1. Add PBXFileReference entry (after HeritageOnDemandService.swift)
sed -i '' "/C5A7C0462F187FB400D99B07 \/\* HeritageOnDemandService.swift \*\//a\\
		$FILE_REF_UUID /* $FILE_NAME */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $FILE_NAME; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"

# 2. Add PBXBuildFile entry (after HeritageOnDemandService.swift in Sources)
sed -i '' "/C5A7C0472F187FB400D99B07 \/\* HeritageOnDemandService.swift in Sources \*\//a\\
		${BUILD_FILE_UUID} /* $FILE_NAME in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_UUID /* $FILE_NAME */; };
" "$PROJECT_FILE"

# 3. Add to group (in the Heritage folder group, after HeritageOnDemandService.swift)
sed -i '' "/C5A7C0462F187FB400D99B07 \/\* HeritageOnDemandService.swift \*\//a\\
				$FILE_REF_UUID /* $FILE_NAME */,
" "$PROJECT_FILE"

# 4. Add to sources build phase (after HeritageOnDemandService.swift in Sources)
sed -i '' "/C5A7C0472F187FB400D99B07 \/\* HeritageOnDemandService.swift in Sources \*\//a\\
				${BUILD_FILE_UUID} /* $FILE_NAME in Sources */,
" "$PROJECT_FILE"

echo "File added to Xcode project successfully!"
echo "Backup saved at ${PROJECT_FILE}.backup"
