import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const db = () => admin.firestore();

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ScheduleData {
  dayOfWeek: number; // 1=Monday … 7=Sunday
  startTime: string; // "HH:mm"
  endTime: string;   // "HH:mm"
  isActive: boolean;
}

// ---------------------------------------------------------------------------
// createSchedule
// ---------------------------------------------------------------------------

export const createSchedule = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const data = request.data as ScheduleData;

    if (!data.dayOfWeek || data.dayOfWeek < 1 || data.dayOfWeek > 7) {
      throw new HttpsError("invalid-argument", "Día de la semana inválido (1–7).");
    }
    if (!data.startTime || !data.endTime) {
      throw new HttpsError("invalid-argument", "Hora de inicio y fin son requeridas.");
    }
    if (data.startTime >= data.endTime) {
      throw new HttpsError("invalid-argument", "La hora de inicio debe ser anterior a la hora de fin.");
    }

    const ref = db().collection("schedules").doc();
    await ref.set({
      dayOfWeek: Number(data.dayOfWeek),
      startTime: data.startTime.trim(),
      endTime: data.endTime.trim(),
      isActive: data.isActive !== false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Schedule created", ref.id);
    return { id: ref.id };
  }
);

// ---------------------------------------------------------------------------
// updateSchedule
// ---------------------------------------------------------------------------

export const updateSchedule = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { id, ...fields } = request.data as { id: string } & Partial<ScheduleData>;

    if (!id) {
      throw new HttpsError("invalid-argument", "Se requiere el ID del horario.");
    }

    if (fields.startTime && fields.endTime && fields.startTime >= fields.endTime) {
      throw new HttpsError("invalid-argument", "La hora de inicio debe ser anterior a la hora de fin.");
    }

    await db()
      .collection("schedules")
      .doc(id)
      .update({
        ...fields,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.info("Schedule updated", id);
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// deleteSchedule
// ---------------------------------------------------------------------------

export const deleteSchedule = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { id } = request.data as { id: string };

    if (!id) {
      throw new HttpsError("invalid-argument", "Se requiere el ID del horario.");
    }

    await db().collection("schedules").doc(id).delete();

    logger.info("Schedule deleted", id);
    return { success: true };
  }
);
