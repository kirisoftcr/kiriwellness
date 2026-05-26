import * as admin from "firebase-admin";
import { createHash } from "crypto";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { getAdminEmail, SECRET_NAMES, sendEmail } from "../config/brevo";
import { verificationCodeHtml } from "../config/email_templates";

const db = () => admin.firestore();

function formatAmPm(time24: string): string {
  const [hStr, mStr] = time24.split(":");
  const h = parseInt(hStr, 10);
  const m = parseInt(mStr, 10);
  const period = h >= 12 ? "PM" : "AM";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${m.toString().padStart(2, "0")} ${period}`;
}

async function sendAdminActionEmail(
  action: "confirmed" | "cancelled",
  appointmentData: FirebaseFirestore.DocumentData,
  clientData: FirebaseFirestore.DocumentData
): Promise<void> {
  const actionLabel = action === "confirmed" ? "confirmó" : "canceló";
  const emoji = action === "confirmed" ? "✅" : "❌";
  const color = action === "confirmed" ? "#2E7D32" : "#c0392b";
  const clientName = `${clientData["firstName"] ?? ""} ${clientData["lastName"] ?? ""}`.trim();
  const time = formatAmPm(appointmentData["time"] ?? "");

  // Resolve admin recipients from Firestore settings, fall back to secret
  const settingsSnap = await admin.firestore().collection("settings").doc("global").get();
  const adminEmails: string[] = settingsSnap.data()?.["adminEmails"] ?? [];
  const adminRecipients = adminEmails.length > 0
    ? adminEmails.map((e) => ({ email: e, name: "Kiri Wellness Admin" }))
    : [{ email: getAdminEmail(), name: "Kiri Wellness Admin" }];

  await sendEmail({
    to: adminRecipients,
    subject: `${emoji} Cliente ${actionLabel} cita – ${appointmentData["serviceName"]}`,
    htmlContent: `
<!DOCTYPE html><html lang="es"><body style="font-family:Arial,sans-serif;background:#F9F6F2;padding:32px;">
<div style="max-width:520px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
  <h2 style="color:${color};margin:0 0 8px">${emoji} Cita ${action === "confirmed" ? "Confirmada" : "Cancelada"}</h2>
  <p style="color:#555;margin:0 0 24px">Un cliente ${actionLabel} su cita desde el portal.</p>
  <table style="width:100%;border-collapse:collapse;font-size:14px;">
    <tr><td style="padding:8px 0;color:#888;width:140px">Cliente</td><td style="padding:8px 0;font-weight:600">${clientName}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Servicio</td><td style="padding:8px 0">${appointmentData["serviceName"] ?? "—"}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Fecha</td><td style="padding:8px 0">${appointmentData["date"] ?? "—"}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Hora</td><td style="padding:8px 0">${time}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Código cliente</td><td style="padding:8px 0">${clientData["clientCode"] ?? "—"}</td></tr>
    <tr><td style="padding:8px 0;color:#888">Teléfono</td><td style="padding:8px 0">${clientData["phone"] ?? "—"}</td></tr>
  </table>
</div>
</body></html>`,
  });
}

// ---------------------------------------------------------------------------
// lookupClientByEmail
// ---------------------------------------------------------------------------

export const lookupClientByEmail = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const { email } = request.data as { email: string };
    if (!email) return { found: false };

    const snap = await db()
      .collection("clients")
      .where("email", "==", email.toLowerCase().trim())
      .limit(1)
      .get();

    if (snap.empty) return { found: false };

    const clientDoc = snap.docs[0];
    const d = clientDoc.data();
    const clientId = clientDoc.id;

    // Also fetch pending rewards so the booking page can show them
    // without requiring direct Firestore access (which is auth-protected).
    let pendingRewards: object[] = [];
    try {
      const rewardsSnap = await db()
        .collection("clients")
        .doc(clientId)
        .collection("rewards")
        .where("status", "==", "pending")
        .get();
      pendingRewards = rewardsSnap.docs.map((r) => ({ id: r.id, ...r.data() }));
    } catch (_) {
      // If rewards can't be fetched, just return empty — non-critical
    }

    return {
      found: true,
      clientId,
      firstName: d["firstName"] ?? d["name"] ?? "",
      lastName: d["lastName"] ?? "",
      phone: d["phone"] ?? "",
      clientCode: d["clientCode"] ?? "",
      email: d["email"] ?? "",
      pendingRewards,
    };
  }
);

// ---------------------------------------------------------------------------
// sendVerificationCode  — sends a 6-digit OTP to client email
// ---------------------------------------------------------------------------

export const sendVerificationCode = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false, secrets: SECRET_NAMES },
  async (request) => {
    const { email } = request.data as { email: string };
    if (!email) throw new HttpsError("invalid-argument", "Email requerido.");

    // Check client exists
    const snap = await db()
      .collection("clients")
      .where("email", "==", email.toLowerCase().trim())
      .limit(1)
      .get();

    if (snap.empty) {
      // Return success silently (security: don't reveal whether email exists)
      return { sent: true };
    }

    const clientData = snap.docs[0].data();
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const hash = createHash("sha256").update(code).digest("hex");
    const expiresAt = Date.now() + 15 * 60 * 1000; // 15 minutes

    await db().collection("verification_codes").doc(email.toLowerCase().trim()).set({
      hash,
      expiresAt,
      clientId: snap.docs[0].id,
    });

    await sendEmail({
      to: [{ email: email.trim(), name: clientData["firstName"] as string }],
      subject: `${code} es tu código de verificación – Kiri Wellness`,
      htmlContent: verificationCodeHtml({
        clientName: clientData["firstName"] as string,
        code,
      }),
    });

    logger.info("Verification code sent to", email);
    return { sent: true };
  }
);

// ---------------------------------------------------------------------------
// verifyClientCode  — validates OTP and returns client appointments
// ---------------------------------------------------------------------------

export const verifyClientCode = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const { email, code } = request.data as { email: string; code: string };
    if (!email || !code) throw new HttpsError("invalid-argument", "Email y código requeridos.");

    const normalizedEmail = email.toLowerCase().trim();
    const verificationDoc = await db().collection("verification_codes").doc(normalizedEmail).get();

    if (!verificationDoc.exists) {
      throw new HttpsError("not-found", "Código inválido o expirado.");
    }

    const vData = verificationDoc.data()!;
    const hash = createHash("sha256").update(code).digest("hex");

    if (vData["hash"] !== hash) {
      throw new HttpsError("unauthenticated", "Código incorrecto.");
    }

    if (Date.now() > (vData["expiresAt"] as number)) {
      throw new HttpsError("deadline-exceeded", "El código ha expirado. Solicita uno nuevo.");
    }

    // Delete used code
    await verificationDoc.ref.delete();

    const clientId = vData["clientId"] as string;

    // Return client's appointments ordered by date desc
    const apptSnap = await db()
      .collection("appointments")
      .where("clientId", "==", clientId)
      .orderBy("date", "desc")
      .orderBy("time", "desc")
      .get();

    const appointments = apptSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

    // Get client data
    const clientDoc = await db().collection("clients").doc(clientId).get();
    const clientData = clientDoc.exists ? clientDoc.data() : {};

    return {
      valid: true,
      clientId,
      client: clientData,
      appointments,
    };
  }
);

// ---------------------------------------------------------------------------
// cancelAppointmentByClient — client self-cancels
// ---------------------------------------------------------------------------

export const cancelAppointmentByClient = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false, secrets: SECRET_NAMES },
  async (request) => {
    const { appointmentId, clientId } = request.data as {
      appointmentId: string;
      clientId: string;
    };

    if (!appointmentId || !clientId) {
      throw new HttpsError("invalid-argument", "Parámetros requeridos.");
    }

    const apptRef = db().collection("appointments").doc(appointmentId);
    const apptSnap = await apptRef.get();

    if (!apptSnap.exists) {
      throw new HttpsError("not-found", "Cita no encontrada.");
    }

    const apptData = apptSnap.data()!;

    if (apptData["clientId"] !== clientId) {
      throw new HttpsError("permission-denied", "No tienes permiso para cancelar esta cita.");
    }

    if (!["requested", "confirmed"].includes(apptData["status"] as string)) {
      throw new HttpsError("failed-precondition", "Esta cita no puede ser cancelada.");
    }

    await apptRef.update({
      status: "cancelled",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify admin
    try {
      const clientSnap = await db().collection("clients").doc(clientId).get();
      await sendAdminActionEmail("cancelled", apptData, clientSnap.data() ?? {});
    } catch (e) {
      logger.warn("Failed to send cancel notification to admin", e);
    }

    logger.info("Appointment cancelled by client", appointmentId);
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// confirmAppointmentByClient — client confirms their appointment
// ---------------------------------------------------------------------------

export const confirmAppointmentByClient = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false, secrets: SECRET_NAMES },
  async (request) => {
    const { appointmentId, clientId } = request.data as {
      appointmentId: string;
      clientId: string;
    };

    if (!appointmentId || !clientId) {
      throw new HttpsError("invalid-argument", "Parámetros requeridos.");
    }

    const apptRef = db().collection("appointments").doc(appointmentId);
    const apptSnap = await apptRef.get();

    if (!apptSnap.exists) {
      throw new HttpsError("not-found", "Cita no encontrada.");
    }

    const apptData = apptSnap.data()!;

    if (apptData["clientId"] !== clientId) {
      throw new HttpsError("permission-denied", "No tienes permiso para confirmar esta cita.");
    }

    if (apptData["status"] !== "requested") {
      throw new HttpsError("failed-precondition", "Esta cita no puede ser confirmada.");
    }

    await apptRef.update({
      status: "confirmed",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notify admin
    try {
      const clientSnap = await db().collection("clients").doc(clientId).get();
      await sendAdminActionEmail("confirmed", apptData, clientSnap.data() ?? {});
    } catch (e) {
      logger.warn("Failed to send confirm notification to admin", e);
    }

    logger.info("Appointment confirmed by client", appointmentId);
    return { success: true };
  }
);

// ---------------------------------------------------------------------------
// getMyAppointments — fetch appointments by clientId (used after OTP auth)
// ---------------------------------------------------------------------------

export const getMyAppointments = onCall(
  { region: "us-central1", invoker: "public", enforceAppCheck: false },
  async (request) => {
    const { clientId } = request.data as { clientId: string };
    if (!clientId) throw new HttpsError("invalid-argument", "clientId requerido.");

    const aptsSnap = await db()
      .collection("appointments")
      .where("clientId", "==", clientId)
      .orderBy("date", "desc")
      .orderBy("time", "desc")
      .get();

    const appointments = aptsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    return { appointments };
  }
);
