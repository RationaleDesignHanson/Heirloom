import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../.env") });
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, "../../../service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}
const db = admin.firestore();

async function fixCollections() {
  const userId = "mQv9mWkCZyQirFrl1f1RFZCbYC02"; // tester03
  
  // Delete duplicate Generated Recipes (keep the first one)
  await db.collection("users").doc(userId).collection("collections").doc("b544fc84-a863-4e52-976d-5964014608c8").delete();
  console.log("✓ Deleted duplicate Generated Recipes collection");
  
  // Verify
  const snapshot = await db.collection("users").doc(userId).collection("collections").get();
  console.log("\nRemaining collections:", snapshot.size);
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    console.log("- " + data.name);
  });
}

fixCollections().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
