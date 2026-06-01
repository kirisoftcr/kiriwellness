import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { firestoreForCallable } from "../config/firestore_db";

/**
 * Returns available time slots for a given date and service.
 * Considers:
 *  - Schedule blocks defined for that weekday
 *  - Existing appointments + service duration + configurable break time
 *
 * Request: { date: "YYYY-MM-DD", serviceId: string }
 * Response: { slots: string[] }  e.g. ["08:00","08:30","09:00"]
 */
export const getAvailableSlots = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
      const db = firestoreForCallable(request);

    const { date, serviceId } = request.data as { date: string; serviceId: string };

    if (!date || !serviceId) {
      return { slots: [] };
    }

    // Parse target date
    const [year, month, day] = date.split("-").map(Number);
    const targetDate = new Date(year, month - 1, day);
    const isoWeekday = targetDate.getDay() === 0 ? 7 : targetDate.getDay(); // 1=Mon..7=Sun

    // 1. Get settings (break time)
    const settingsSnap = await db.collection("settings").doc("global").get();
    const breakMinutes: number = settingsSnap.exists
      ? ((settingsSnap.data()?.["breakMinutes"] as number) ?? 30)
      : 30;

    // 2. Get the service duration
    const serviceSnap = await db.collection("services").doc(serviceId).get();
    if (!serviceSnap.exists) return { slots: [] };
    const serviceDurationMin: number = (serviceSnap.data()?.["durationMinutes"] as number) ?? 60;

    // 3. Get active schedule blocks for this weekday
    const scheduleSnap = await db
      .collection("schedules")
      .where("dayOfWeek", "==", isoWeekday)
      .where("isActive", "==", true)
      .get();

    if (scheduleSnap.empty) return { slots: [] };

    // 4. Get all non-cancelled appointments for this date
    const apptSnap = await db
      .collection("appointments")
      .where("date", "==", date)
      .where("status", "in", ["requested", "confirmed"])
      .get();

    // Build list of blocked intervals [startMin, endMin]
    const blocked: Array<[number, number]> = apptSnap.docs.map((doc) => {
      const d = doc.data();
      const [h, m] = (d["time"] as string).split(":").map(Number);
      const startMin = h * 60 + m;
      const duration: number = (d["serviceDurationMin"] as number) ?? 60;
      return [startMin, startMin + duration + breakMinutes];
    });

    // 5. Generate every 30-min slot within each schedule block
    //    and filter out slots that:
    //     - Are blocked by an existing appointment
    //     - Don't have enough time for the service within the block
    const availableSlots: string[] = [];

    for (const blockDoc of scheduleSnap.docs) {
      const blockData = blockDoc.data();
      const [bStartH, bStartM] = (blockData["startTime"] as string).split(":").map(Number);
      const [bEndH, bEndM] = (blockData["endTime"] as string).split(":").map(Number);
      const blockStart = bStartH * 60 + bStartM;
      const blockEnd = bEndH * 60 + bEndM;

      let cursor = blockStart;
      while (cursor + serviceDurationMin <= blockEnd) {
        const slotEnd = cursor + serviceDurationMin;
        // Check no overlap with blocked intervals
        const isBlocked = blocked.some(([bStart, bEnd]) => {
          return cursor < bEnd && slotEnd > bStart;
        });

        if (!isBlocked) {
          const hh = Math.floor(cursor / 60).toString().padStart(2, "0");
          const mm = (cursor % 60).toString().padStart(2, "0");
          availableSlots.push(`${hh}:${mm}`);
        }
        cursor += 30; // 30-min granularity
      }
    }

    // Deduplicate and sort
    const unique = [...new Set(availableSlots)].sort();
    logger.info(`Available slots for ${date} (service ${serviceId}):`, unique.length);
    return { slots: unique };
  }
);
