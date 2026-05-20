import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAdminEmail, SECRET_NAMES, sendEmail } from "../config/brevo";
import { adminBookingNotificationHtml, appointmentConfirmedClientHtml } from "../config/email_templates";

const db = () => admin.firestore();

// ---------------------------------------------------------------------------
// getSettings (public — used by booking flow to know break time)
// ---------------------------------------------------------------------------

export const getSettings = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async () => {
    const snap = await db().collection("settings").doc("global").get();
    if (!snap.exists) {
      return { breakMinutes: 30, cancellationHoursLimit: 24, allowSameDayBooking: true };
    }
    return snap.data();
  }
);

// ---------------------------------------------------------------------------
// updateSettings (admin only)
// ---------------------------------------------------------------------------

export const updateSettings = onCall(
  { region: "us-central1", invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { breakMinutes, cancellationHoursLimit, allowSameDayBooking, adminEmails } = request.data as {
      breakMinutes?: number;
      cancellationHoursLimit?: number;
      allowSameDayBooking?: boolean;
      adminEmails?: string[];
    };

    const updates: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (breakMinutes !== undefined) updates["breakMinutes"] = Number(breakMinutes);
    if (cancellationHoursLimit !== undefined) updates["cancellationHoursLimit"] = Number(cancellationHoursLimit);
    if (allowSameDayBooking !== undefined) updates["allowSameDayBooking"] = Boolean(allowSameDayBooking);
    if (adminEmails !== undefined) updates["adminEmails"] = adminEmails.map((e) => e.trim().toLowerCase()).filter(Boolean);

    await db().collection("settings").doc("global").set(updates, { merge: true });

    logger.info("Settings updated");
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// updateAppointmentStatus (admin only)
// ---------------------------------------------------------------------------

export const updateAppointmentStatus = onCall(
  { region: "us-central1", invoker: "public", secrets: [...SECRET_NAMES] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { appointmentId, status } = request.data as {
      appointmentId: string;
      status: string;
    };

    const validStatuses = ["requested", "confirmed", "cancelled", "completed"];
    if (!validStatuses.includes(status)) {
      throw new HttpsError("invalid-argument", "Estado inválido.");
    }

    await db().collection("appointments").doc(appointmentId).update({
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Appointment ${appointmentId} status updated to ${status}`);

    // ── Send emails when admin confirms or cancels ─────────────────────────
    if (status === "confirmed" || status === "cancelled") {
      try {
        const aptSnap = await db().collection("appointments").doc(appointmentId).get();
        const apt = aptSnap.data();
        if (!apt) throw new Error("Appointment not found");

        const clientSnap = await db().collection("clients").doc(apt["clientId"]).get();
        const client = clientSnap.data();

        // Format date
        const [year, month, day] = (apt["date"] as string).split("-").map(Number);
        const dateObj = new Date(year, month - 1, day);
        const formattedDate = dateObj.toLocaleDateString("es-CR", {
          weekday: "long", year: "numeric", month: "long", day: "numeric",
        });

        // Build Google Calendar URL
        const durationMin: number = apt["serviceDurationMin"] ?? 60;
        const [hour, minute] = (apt["time"] as string).split(":").map(Number);
        const startDt = new Date(year, month - 1, day, hour, minute);
        const endDt = new Date(startDt.getTime() + durationMin * 60 * 1000);
        const fmt = (d: Date) =>
          `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}T${String(d.getHours()).padStart(2, "0")}${String(d.getMinutes()).padStart(2, "0")}00`;
        const gcParams = new URLSearchParams({
          action: "TEMPLATE",
          text: `Kiri Wellness – ${apt["serviceName"]}`,
          dates: `${fmt(startDt)}/${fmt(endDt)}`,
          details: `Servicio: ${apt["serviceName"]}`,
          location: "Kiri Wellness, Costa Rica",
        });
        const googleCalendarUrl = `https://calendar.google.com/calendar/render?${gcParams.toString()}`;

        const baseUrl = "https://kiriwellness.com";
        const clientToken: string | undefined = client?.["clientToken"];
        const myAppointmentsUrl = clientToken
          ? `${baseUrl}/#/my-appointments?token=${clientToken}`
          : `${baseUrl}/#/my-appointments`;

        // Resolve admin email recipients
        const settingsSnap = await db().collection("settings").doc("global").get();
        const adminEmails: string[] = settingsSnap.data()?.["adminEmails"] ?? [];
        const adminRecipients = adminEmails.length > 0
          ? adminEmails.map((e) => ({ email: e, name: "Kiri Wellness Admin" }))
          : [{ email: getAdminEmail(), name: "Kiri Wellness Admin" }];

        const commonParams = {
          clientName: client?.["firstName"] ?? client?.["name"] ?? "",
          clientLastName: client?.["lastName"] ?? "",
          clientCode: client?.["clientCode"] ?? "",
          clientPhone: client?.["phone"] ?? "",
          clientEmail: client?.["email"] ?? "",
          serviceName: apt["serviceName"] ?? "",
          date: formattedDate,
          time: apt["time"] ?? "",
          notes: apt["notes"] || undefined,
          isNewClient: false,
        };

        // Notify client
        const clientEmail: string | undefined = client?.["email"];
        if (clientEmail && status === "confirmed") {
          await sendEmail({
            to: [{ email: clientEmail, name: commonParams.clientName }],
            subject: `✅ Cita confirmada – ${apt["serviceName"]} el ${formattedDate}`,
            htmlContent: appointmentConfirmedClientHtml({
              clientName: commonParams.clientName,
              clientCode: commonParams.clientCode,
              serviceName: commonParams.serviceName,
              date: formattedDate,
              time: commonParams.time,
              notes: commonParams.notes,
              myAppointmentsUrl,
              googleCalendarUrl,
            }),
          });
          logger.info("Confirmation email sent to client", clientEmail);
        }

        // Notify all admin recipients
        const adminSubject = status === "confirmed"
          ? `✅ Cita confirmada – ${commonParams.clientName} ${commonParams.clientLastName} · ${apt["serviceName"]}`
          : `❌ Cita cancelada – ${commonParams.clientName} ${commonParams.clientLastName} · ${apt["serviceName"]}`;
        await sendEmail({
          to: adminRecipients,
          subject: adminSubject,
          htmlContent: adminBookingNotificationHtml({
            ...commonParams,
            event: status === "confirmed" ? "confirmed" : "cancelled",
          }),
        });
        logger.info(`Admin notification sent for status: ${status}`);
      } catch (emailErr) {
        // Don't fail the function — the status update already succeeded
        logger.warn("Email sending failed after confirmation", emailErr);
      }
    }

    return { success: true };
  }
);
