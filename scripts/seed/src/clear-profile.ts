import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../.env") });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, "../../../service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}
const db = admin.firestore();

async function clearProfile() {
  const userId = "mQv9mWkCZyQirFrl1f1RFZCbYC02";
  await db.collection("users").doc(userId).collection("profile").doc("data").delete();
  await db.collection("userProfiles").doc(userId).delete();
  console.log("Profile cleared for tester03");
}

clearProfile().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
