import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../.env") });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, "../../../service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}
const db = admin.firestore();

async function checkProfile() {
  const userId = "mQv9mWkCZyQirFrl1f1RFZCbYC02";
  
  console.log("Checking profile for tester03...\n");
  
  // Check users/{userId}/profile/data
  const profileDoc = await db.collection("users").doc(userId).collection("profile").doc("data").get();
  console.log("Path: users/{userId}/profile/data");
  console.log("Exists:", profileDoc.exists);
  if (profileDoc.exists) {
    console.log("Data:", JSON.stringify(profileDoc.data(), null, 2));
  }
  
  console.log("\n---\n");
  
  // Check userProfiles/{userId}
  const legacyDoc = await db.collection("userProfiles").doc(userId).get();
  console.log("Path: userProfiles/{userId}");
  console.log("Exists:", legacyDoc.exists);
  if (legacyDoc.exists) {
    console.log("Data:", JSON.stringify(legacyDoc.data(), null, 2));
  }
}

checkProfile().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
