import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAdminEmail, SECRET_NAMES, sendEmail } from "../config/brevo";
import { adminBookingNotificationHtml, appointmentConfirmedClientHtml, appointmentThankYouHtml } from "../config/email_templates";
import { checkAndGrantRewards, buildLoyaltyProgressHtml } from "../loyalty/loyalty_crud";
import { usePackageSession } from "../packages/packages_crud";
import { firestoreForCallable } from "../config/firestore_db";
import { sendWhatsAppWithFallback } from "../config/whatsapp";
import {
  whatsAppBookingConfirmedMessage,
  whatsAppBookingCancelledMessage,
  whatsAppThankYouMessage,
  bookingConfirmedTemplateComponents,
  bookingCancelledTemplateComponents,
  appointmentThankyouTemplateComponents,
  WHATSAPP_TEMPLATE_NAMES,
  WHATSAPP_TEMPLATE_LANGUAGE,
} from "../config/whatsapp_templates";

// ---------------------------------------------------------------------------
// getSettings (public — used by booking flow to know break time)
// ---------------------------------------------------------------------------

export const getSettings = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const database = firestoreForCallable(request);
    const snap = await database.collection("settings").doc("global").get();
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
    const database = firestoreForCallable(request);

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

    await database.collection("settings").doc("global").set(updates, { merge: true });

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
    const database = firestoreForCallable(request);

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

    await database.collection("appointments").doc(appointmentId).update({
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Appointment ${appointmentId} status updated to ${status}`);

    // ── Loyalty: check and grant rewards when a cita is completed ──────────
    if (status === "completed") {
      try {
        const aptSnap = await database.collection("appointments").doc(appointmentId).get();
        const apt = aptSnap.data();
        if (apt?.["clientId"]) {
          const isPackageAppointment = !!(apt["clientPackageId"]);

          if (isPackageAppointment) {
            // ── Package appointment: use a session from the client package ──
            await usePackageSession(apt["clientPackageId"] as string, apt["serviceId"] as string, database);
            logger.info("Package session used for appointment", appointmentId);
          } else {
            // ── Regular appointment: increment counter and check loyalty ───
            const clientRef = database.collection("clients").doc(apt["clientId"]);
            await clientRef.update({
              completedAppointments: admin.firestore.FieldValue.increment(1),
            });
            const clientSnap = await clientRef.get();
            const completedCount: number = clientSnap.data()?.["completedAppointments"] ?? 1;
            await checkAndGrantRewards(apt["clientId"], completedCount, database);
          }

          // ── Thank-you email to client (all appointment types) ────────────
          const clientRef2 = database.collection("clients").doc(apt["clientId"]);
          const clientSnap2 = await clientRef2.get();
          const clientEmail: string | undefined = clientSnap2.data()?.["email"];
          if (clientEmail) {
            try {
              const clientName: string = clientSnap2.data()?.["name"] ?? clientSnap2.data()?.["firstName"] ?? "Cliente";
              const clientCode: string = clientSnap2.data()?.["clientCode"] ?? "";
              const clientToken: string | undefined = clientSnap2.data()?.["clientToken"];
              const baseUrl = "https://kiriwellness.com";
              const myAppointmentsUrl = clientToken
                ? `${baseUrl}/#/my-appointments?token=${clientToken}`
                : `${baseUrl}/#/my-appointments`;

              const [aptYear, aptMonth, aptDay] = (apt["date"] as string).split("-").map(Number);
              const aptDateObj = new Date(aptYear, aptMonth - 1, aptDay);
              const formattedAptDate = aptDateObj.toLocaleDateString("es-CR", {
                weekday: "long", year: "numeric", month: "long", day: "numeric",
              });

              const loyaltyProgressHtml = isPackageAppointment
                ? undefined
                : (await buildLoyaltyProgressHtml(apt["clientId"], database) ?? undefined);

              await sendEmail({
                to: [{ email: clientEmail, name: clientName }],
                subject: `🌿 ¡Gracias por tu visita, ${clientName}! – Kiri Wellness`,
                htmlContent: appointmentThankYouHtml({
                  clientName,
                  clientCode,
                  serviceName: apt["serviceName"] ?? "",
                  date: formattedAptDate,
                  myAppointmentsUrl,
                  loyaltyProgressHtml,
                }),
              });
              logger.info(`Thank-you email sent to ${clientEmail}`);
            } catch (thankYouErr) {
              logger.warn("Thank-you email failed", thankYouErr);
            }
          }

          // ── WhatsApp thank-you message ─────────────────────────────────
          const clientPhone: string | undefined = clientSnap2.data()?.["phone"];
          if (clientPhone) {
            const baseUrlWA = "https://kiriwellness.com";
            const clientTokenWA: string | undefined = clientSnap2.data()?.["clientToken"];
            const myAppointmentsUrlWA = clientTokenWA
              ? `${baseUrlWA}/#/my-appointments?token=${clientTokenWA}`
              : `${baseUrlWA}/#/my-appointments`;
            const thankYouParams = {
              clientName: clientSnap2.data()?.["firstName"] ?? clientSnap2.data()?.["name"] ?? "Cliente",
              serviceName: apt["serviceName"] ?? "",
              myAppointmentsUrl: myAppointmentsUrlWA,
            };
            await sendWhatsAppWithFallback(
              clientPhone,
              whatsAppThankYouMessage(thankYouParams),
              WHATSAPP_TEMPLATE_NAMES.appointmentThankyou,
              WHATSAPP_TEMPLATE_LANGUAGE,
              appointmentThankyouTemplateComponents(thankYouParams)
            );
          }
        }
      } catch (loyaltyErr) {
        // Never fail the status update because of loyalty/package logic
        logger.error("Post-completion hook failed", loyaltyErr);
      }
    }

    // ── Send emails when admin confirms or cancels ─────────────────────────
    if (status === "confirmed" || status === "cancelled") {
      try {
        const aptSnap = await database.collection("appointments").doc(appointmentId).get();
        const apt = aptSnap.data();
        if (!apt) throw new Error("Appointment not found");

        const clientSnap = await database.collection("clients").doc(apt["clientId"]).get();
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
        const settingsSnap = await database.collection("settings").doc("global").get();
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
          const loyaltyProgressHtml = await buildLoyaltyProgressHtml(apt["clientId"], database);
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
              loyaltyProgressHtml: loyaltyProgressHtml ?? undefined,
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

        // ── WhatsApp notification to client ────────────────────────────────
        const clientPhone: string | undefined = client?.["phone"];
        if (clientPhone) {
          if (status === "confirmed") {
            const confirmedParams = {
              clientName: commonParams.clientName,
              serviceName: commonParams.serviceName,
              date: formattedDate,
              time: commonParams.time,
              myAppointmentsUrl,
            };
            await sendWhatsAppWithFallback(
              clientPhone,
              whatsAppBookingConfirmedMessage(confirmedParams),
              WHATSAPP_TEMPLATE_NAMES.bookingConfirmed,
              WHATSAPP_TEMPLATE_LANGUAGE,
              bookingConfirmedTemplateComponents(confirmedParams)
            );
          } else {
            const cancelledParams = {
              clientName: commonParams.clientName,
              serviceName: commonParams.serviceName,
              date: formattedDate,
              time: commonParams.time,
            };
            await sendWhatsAppWithFallback(
              clientPhone,
              whatsAppBookingCancelledMessage(cancelledParams),
              WHATSAPP_TEMPLATE_NAMES.bookingCancelled,
              WHATSAPP_TEMPLATE_LANGUAGE,
              bookingCancelledTemplateComponents(cancelledParams)
            );
          }
        }
      } catch (emailErr) {
        // Don't fail the function — the status update already succeeded
        logger.warn("Email sending failed after confirmation", emailErr);
      }
    }

    return { success: true };
  }
);
