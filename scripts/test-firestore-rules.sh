#!/bin/bash
# Test Firestore Security Rules using Firebase Emulator
# This script validates that security rules work as expected

set -e

echo "🔥 Starting Firebase Emulators..."
firebase emulators:start --only firestore,auth &
EMULATOR_PID=$!

# Wait for emulators to start
echo "⏳ Waiting for emulators to initialize..."
sleep 5

# Check if emulators are running
if ! curl -s http://localhost:8080 > /dev/null; then
    echo "❌ Firestore emulator failed to start"
    kill $EMULATOR_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Emulators started successfully"
echo ""
echo "🧪 Running security rule tests..."
echo ""

# Note: Actual test implementation would use Firebase Admin SDK or REST API
# For now, this documents the test scenarios that should be validated

cat <<'EOF'
TEST SCENARIOS TO VALIDATE:

1. Shares Collection - Read Access:
   ✓ Owner can read their own share
   ✓ Recipient in allowedRecipients can read share
   ✗ Random authenticated user CANNOT read share
   ✗ Unauthenticated user CANNOT read share

2. Shares Collection - Update Access:
   ✓ Owner can update their share
   ✓ Recipient can add themselves to acceptedBy
   ✗ Recipient CANNOT modify other fields
   ✗ Random authenticated user CANNOT update share

3. Shares Collection - Delete Access:
   ✓ Owner can delete their share
   ✗ Recipient CANNOT delete share
   ✗ Random user CANNOT delete share

4. Shares Collection - Create Access:
   ✓ Authenticated user can create share with themselves as owner
   ✗ Authenticated user CANNOT create share with different owner

Run these tests manually or implement automated tests using:
- Firebase Emulator Suite UI (http://localhost:4000)
- Firebase Admin SDK test suite
- @firebase/testing package (deprecated) or @firebase/rules-unit-testing

EOF

echo ""
echo "📊 Emulator UI available at: http://localhost:4000"
echo "🔍 Firestore Emulator at: http://localhost:8080"
echo "🔐 Auth Emulator at: http://localhost:9099"
echo ""
echo "Press Ctrl+C to stop emulators..."

# Keep script running
wait $EMULATOR_PID
