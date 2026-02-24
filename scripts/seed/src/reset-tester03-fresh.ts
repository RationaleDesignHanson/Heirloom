import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../.env") });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, "../../../service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}
const db = admin.firestore();

async function clearAllData() {
  const userId = "mQv9mWkCZyQirFrl1f1RFZCbYC02";

  console.log("Clearing ALL data for tester03...\n");

  // Clear profile
  await db.collection("users").doc(userId).collection("profile").doc("data").delete();
  await db.collection("userProfiles").doc(userId).delete();
  console.log("✓ Profile cleared");

  // Clear recipes
  const recipes = await db.collection("users").doc(userId).collection("recipes").listDocuments();
  for (const doc of recipes) {
    await doc.delete();
  }
  console.log(`✓ Deleted ${recipes.length} recipes`);

  // Clear collections
  const collections = await db.collection("users").doc(userId).collection("collections").listDocuments();
  for (const doc of collections) {
    await doc.delete();
  }
  console.log(`✓ Deleted ${collections.length} collections`);

  // Clear themeState
  const themeState = await db.collection("users").doc(userId).collection("themeState").listDocuments();
  for (const doc of themeState) {
    await doc.delete();
  }
  console.log(`✓ Deleted ${themeState.length} themeState docs`);

  // Clear connections
  const connections = await db.collection("users").doc(userId).collection("connections").listDocuments();
  for (const doc of connections) {
    await doc.delete();
  }
  console.log(`✓ Deleted ${connections.length} connections`);

  console.log("\n✅ tester03 is now a completely fresh new user");
}

clearAllData().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
