import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getAdminEmail, SECRET_NAMES, sendEmail } from "../config/brevo";
import {
  adminBookingNotificationHtml,
  bookingConfirmationHtml,
} from "../config/email_templates";

interface AppointmentData {
  clientId: string;
  serviceId: string;
  serviceName: string;
  date: string; // "YYYY-MM-DD"
  time: string; // "HH:mm"
  notes?: string;
  status: string;
}

interface ClientData {
  firstName: string;
  lastName: string;
  phone: string;
  email?: string;
  clientCode: string;
  isNew?: boolean;
}

/**
 * Firestore trigger: fires when a new appointment document is created.
 * Sends a confirmation email to the client and a notification email to admin.
 */
export const onAppointmentCreated = onDocumentCreated(
  {
    document: "appointments/{appointmentId}",
    secrets: [...SECRET_NAMES],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const appointment = snap.data() as AppointmentData;

    // Fetch client data
    let client: ClientData | null = null;
    let isNewClient = false;
    try {
      const clientSnap = await admin
        .firestore()
        .collection("clients")
        .doc(appointment.clientId)
        .get();

      if (clientSnap.exists) {
        const d = clientSnap.data()!;
        client = {
          firstName: d["firstName"] ?? "",
          lastName: d["lastName"] ?? "",
          phone: d["phone"] ?? "",
          email: d["email"] ?? "",
          clientCode: d["clientCode"] ?? "",
          isNew: d["isNew"] ?? false,
        };
        isNewClient = d["isNew"] === true;

        // Clear the isNew flag after first booking email
        if (isNewClient) {
          await clientSnap.ref.update({ isNew: false });
        }
      }
    } catch (err) {
      logger.error("Failed to fetch client", err);
    }

    if (!client) {
      logger.warn("No client found for appointment", appointment.clientId);
      return;
    }

    // Format date for display
    const [year, month, day] = appointment.date.split("-");
    const dateObj = new Date(
      parseInt(year),
      parseInt(month) - 1,
      parseInt(day)
    );
    const formattedDate = dateObj.toLocaleDateString("es-CR", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });

    const baseUrl = "https://kiriwellness.com";

    // Fetch clientToken for direct deep link (bypasses email/OTP)
    let clientToken: string | null = null;
    try {
      const clientSnap = await admin
        .firestore()
        .collection("clients")
        .doc(appointment.clientId)
        .get();
      clientToken = clientSnap.data()?.["clientToken"] ?? null;
    } catch (e) {
      logger.warn("Could not fetch clientToken", e);
    }

    const myAppointmentsUrl = clientToken
      ? `${baseUrl}/#/my-appointments?token=${clientToken}`
      : `${baseUrl}/#/my-appointments`;

    const emailParams = {
      clientName: client.firstName,
      clientCode: client.clientCode,
      serviceName: appointment.serviceName,
      date: formattedDate,
      time: appointment.time,
      notes: appointment.notes,
      myAppointmentsUrl,
    };

    const errors: string[] = [];

    // Send confirmation to client (if they have email)
    if (client.email) {
      try {
        await sendEmail({
          to: [{ email: client.email, name: client.firstName }],
          subject: `✅ Cita confirmada – ${appointment.serviceName} el ${formattedDate}`,
          htmlContent: bookingConfirmationHtml(emailParams),
        });
        logger.info("Confirmation email sent to client", client.email);
      } catch (err) {
        errors.push(`client email failed: ${err}`);
        logger.error("Failed to send client confirmation email", err);
      }
    }

    // Resolve admin notification addresses:
    // 1. Read adminEmails from Firestore settings/global
    // 2. Fall back to the ADMIN_EMAIL secret if the list is empty
    let adminRecipients: Array<{ email: string; name: string }> = [];
    try {
      const settingsSnap = await admin.firestore().collection("settings").doc("global").get();
      const adminEmails: string[] = settingsSnap.data()?.["adminEmails"] ?? [];
      adminRecipients = adminEmails
        .filter((e) => !!e)
        .map((e) => ({ email: e, name: "Kiri Wellness Admin" }));
    } catch (e) {
      logger.warn("Could not read adminEmails from settings", e);
    }
    if (adminRecipients.length === 0) {
      adminRecipients = [{ email: getAdminEmail(), name: "Kiri Wellness Admin" }];
    }

    // Send notification to all admin recipients
    try {
      await sendEmail({
        to: adminRecipients,
        subject: `🔔 Nueva cita – ${client.firstName} ${client.lastName} · ${appointment.serviceName}`,
        htmlContent: adminBookingNotificationHtml({
          clientName: client.firstName,
          clientLastName: client.lastName,
          clientCode: client.clientCode,
          clientPhone: client.phone,
          clientEmail: client.email ?? "",
          serviceName: appointment.serviceName,
          date: formattedDate,
          time: appointment.time,
          notes: appointment.notes,
          isNewClient,
        }),
      });
      logger.info("Notification email sent to admin recipients", adminRecipients.map((r) => r.email));
    } catch (err) {
      errors.push(`admin email failed: ${err}`);
      logger.error("Failed to send admin notification email", err);
    }

    if (errors.length > 0) {
      logger.warn("Email errors:", errors);
    }
  }
);
