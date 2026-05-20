import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { SECRET_NAMES, sendEmail } from "../config/brevo";
import { appointmentReminderHtml } from "../config/email_templates";

/**
 * Scheduled function: runs every day at 9:00 AM Costa Rica time (UTC-6).
 * Queries appointments scheduled for tomorrow and sends reminder emails.
 */
export const sendReminders = onSchedule(
  {
    schedule: "0 15 * * *", // 09:00 CR time = 15:00 UTC
    timeZone: "America/Costa_Rica",
    secrets: [...SECRET_NAMES],
  },
  async () => {
    const db = admin.firestore();

    // Compute tomorrow's date in YYYY-MM-DD format
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const year = tomorrow.getFullYear();
    const month = String(tomorrow.getMonth() + 1).padStart(2, "0");
    const day = String(tomorrow.getDate()).padStart(2, "0");
    const tomorrowStr = `${year}-${month}-${day}`;

    logger.info(`Sending reminders for date: ${tomorrowStr}`);

    // Fetch all confirmed/pending appointments for tomorrow
    const snapshot = await db
      .collection("appointments")
      .where("date", "==", tomorrowStr)
      .where("status", "in", ["pending", "confirmed"])
      .get();

    if (snapshot.empty) {
      logger.info("No appointments tomorrow, skipping reminders.");
      return;
    }

    const formattedDate = tomorrow.toLocaleDateString("es-CR", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });

    let sent = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      const apt = doc.data();

      try {
        // Fetch client
        const clientSnap = await db
          .collection("clients")
          .doc(apt["clientId"])
          .get();

        if (!clientSnap.exists) continue;

        const client = clientSnap.data()!;
        const clientEmail: string = client["email"] ?? "";
        const clientName: string = client["firstName"] ?? "cliente";

        if (!clientEmail) {
          logger.info(`No email for client ${apt["clientId"]}, skipping.`);
          continue;
        }

        await sendEmail({
          to: [{ email: clientEmail, name: clientName }],
          subject: `⏰ Recordatorio: tu cita mañana – ${apt["serviceName"]}`,
          htmlContent: appointmentReminderHtml({
            clientName,
            serviceName: apt["serviceName"] ?? "",
            date: formattedDate,
            time: apt["time"] ?? "",
          }),
        });

        sent++;
        logger.info(`Reminder sent to ${clientEmail} for appointment ${doc.id}`);
      } catch (err) {
        failed++;
        logger.error(`Failed to send reminder for appointment ${doc.id}:`, err);
      }
    }

    logger.info(`Reminders done. Sent: ${sent}, Failed: ${failed}`);
  }
);
