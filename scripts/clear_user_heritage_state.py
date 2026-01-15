#!/usr/bin/env python3
"""
Clear a user's heritage state in Firebase to simulate a fresh account.
This allows testing the blind box reveal flow without creating a new account.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys

# Initialize Firebase Admin SDK
cred = credentials.Certificate('backend/firebase-service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def clear_user_heritage_state(user_id: str):
    """Clear all heritage state for a user."""
    print(f"Clearing heritage state for user: {user_id}")

    # Delete heritageState/current document
    heritage_ref = db.collection('users').document(user_id).collection('heritageState').document('current')
    heritage_ref.delete()
    print(f"✅ Deleted heritageState/current")

    print(f"\n✅ User heritage state cleared!")
    print(f"\nNext steps:")
    print(f"1. Delete the Heirloom app from your device/simulator")
    print(f"2. Reinstall the app")
    print(f"3. Sign in with the same account")
    print(f"4. Complete onboarding and tap the blind box")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 clear_user_heritage_state.py <user_id>")
        print("\nYour user ID from logs: 9VUXSm6a3SQTODOcQQW6HD7KOU42")
        sys.exit(1)

    user_id = sys.argv[1]
    clear_user_heritage_state(user_id)
