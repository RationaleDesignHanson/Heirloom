import * as admin from "firebase-admin";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../.env") });
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, "../../../service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}
const db = admin.firestore();

async function checkCollections() {
  const userId = "mQv9mWkCZyQirFrl1f1RFZCbYC02"; // tester03
  const snapshot = await db.collection("users").doc(userId).collection("collections").get();
  console.log("Collections for tester03:", snapshot.size);
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    console.log("- " + doc.id + ": " + data.name + " (isSystemCollection=" + data.isSystemCollection + ", type=" + data.collectionType + ")");
  });
}

checkCollections().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
