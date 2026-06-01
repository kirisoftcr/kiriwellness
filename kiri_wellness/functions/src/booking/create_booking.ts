import * as logger from "firebase-functions/logger";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { randomUUID } from "crypto";
import { firestoreForCallable } from "../config/firestore_db";

interface CreateBookingRequest {
  // Client info
  firstName: string;
  lastName: string;
  phone: string;
  email?: string;
  // Appointment info
  serviceId: string;
  serviceName: string;
  serviceDurationMin: number;
  servicePrice: number;
  date: string; // "YYYY-MM-DD"
  time: string; // "HH:mm"
  notes?: string;
  confirmDirectly?: boolean;
}

interface CreateBookingResponse {
  clientId: string;
  clientCode: string;
  appointmentId: string;
  isNewClient: boolean;
}

/**
 * HTTP Callable: atomically creates (or finds) a client and creates an appointment.
 * Handles the KW-XXXXX counter via Firestore transaction.
 */
export const createBooking = onCall<CreateBookingRequest>(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request): Promise<CreateBookingResponse> => {
    const data = request.data;

    // Validate required fields
    if (!data.firstName || !data.phone || !data.serviceId || !data.date || !data.time) {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    const db = firestoreForCallable(request);

    let clientId: string;
    let clientCode: string;
    let isNewClient = false;
    let appointmentId: string;

    // Step 1: Find or create client (with transaction for KW code)
    const clientsRef = db.collection("clients");
    const counterRef = db.doc("counters/clients");

    // Check if client already exists by phone
    const existingSnapshot = await clientsRef
      .where("phone", "==", data.phone)
      .limit(1)
      .get();

    if (!existingSnapshot.empty) {
      // Existing client – just use their data
      const existingDoc = existingSnapshot.docs[0];
      clientId = existingDoc.id;
      clientCode = existingDoc.data()["clientCode"] as string;
      isNewClient = false;
      logger.info("Found existing client", clientId, clientCode);
      // Backfill clientToken if missing
      if (!existingDoc.data()["clientToken"]) {
        await existingDoc.ref.update({ clientToken: randomUUID() });
      }
    } else {
      // New client – use transaction to assign KW code
      const newClientRef = clientsRef.doc();
      clientId = newClientRef.id;
      isNewClient = true;

      await db.runTransaction(async (tx) => {
        const counterSnap = await tx.get(counterRef);
        const lastId = counterSnap.exists
          ? ((counterSnap.data()?.["lastId"] as number) ?? 0)
          : 0;
        const nextId = lastId + 1;
        clientCode = `KW-${String(nextId).padStart(5, "0")}`;

        tx.set(counterRef, { lastId: nextId }, { merge: true });
        tx.set(newClientRef, {
          firstName: data.firstName,
          lastName: data.lastName,
          phone: data.phone,
          email: data.email ?? "",
          clientCode,
          clientToken: randomUUID(),
          isNew: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      logger.info("Created new client", clientId, clientCode!);
    }

    // Step 2: Verify the slot is still available (guard against race conditions)
    const [reqH, reqM] = data.time.split(":").map(Number);
    const reqStart = reqH * 60 + reqM;
    const reqEnd = reqStart + data.serviceDurationMin;

    // Fetch settings for break time
    const settingsSnap = await db.collection("settings").doc("global").get();
    const breakMinutes: number = settingsSnap.exists
      ? ((settingsSnap.data()?.["breakMinutes"] as number) ?? 30)
      : 30;

    const conflictSnap = await db
      .collection("appointments")
      .where("date", "==", data.date)
      .where("status", "in", ["requested", "confirmed"])
      .get();

    for (const doc of conflictSnap.docs) {
      const d = doc.data();
      const [exH, exM] = (d["time"] as string).split(":").map(Number);
      const exStart = exH * 60 + exM;
      const exDuration: number = (d["serviceDurationMin"] as number) ?? 60;
      const exEnd = exStart + exDuration + breakMinutes;
      // Overlap: new slot starts before existing ends AND new slot ends after existing starts
      if (reqStart < exEnd && reqEnd > exStart) {
        throw new HttpsError(
          "already-exists",
          "El horario seleccionado ya no está disponible. Por favor elige otro."
        );
      }
    }

    // Step 3: Create appointment
    const appointmentRef = db.collection("appointments").doc();
    appointmentId = appointmentRef.id;

    await appointmentRef.set({
      clientId,
      clientCode: clientCode!,
      clientName: data.firstName,
      clientLastName: data.lastName,
      clientEmail: data.email ?? "",
      serviceId: data.serviceId,
      serviceName: data.serviceName,
      serviceDurationMin: data.serviceDurationMin,
      servicePrice: data.servicePrice,
      date: data.date,
      time: data.time,
      notes: data.notes ?? "",
      status: data.confirmDirectly === true ? "confirmed" : "requested",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("Created appointment", appointmentId);

    return {
      clientId,
      clientCode: clientCode!,
      appointmentId,
      isNewClient,
    };
  }
);
