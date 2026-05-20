import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onCall, HttpsError } from "firebase-functions/v2/https";

/**
 * Returns a client's appointments using a secure token embedded in email links.
 * No email/OTP required — the token acts as a bearer credential.
 */
export const getAppointmentsByToken = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const token = (request.data?.token as string | undefined)?.trim();
    if (!token) {
      throw new HttpsError("invalid-argument", "Token requerido.");
    }

    const db = admin.firestore();

    // Look up the client by their token
    const clientSnap = await db
      .collection("clients")
      .where("clientToken", "==", token)
      .limit(1)
      .get();

    if (clientSnap.empty) {
      throw new HttpsError("not-found", "Token inválido o expirado.");
    }

    const clientDoc = clientSnap.docs[0];
    const clientId = clientDoc.id;
    const clientData = clientDoc.data();

    logger.info("getAppointmentsByToken: found client", clientId);

    // Fetch appointments for this client
    const aptsSnap = await db
      .collection("appointments")
      .where("clientId", "==", clientId)
      .orderBy("date", "desc")
      .orderBy("time", "desc")
      .get();

    const appointments = aptsSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      clientId,
      email: clientData["email"] ?? "",
      appointments,
    };
  }
);
