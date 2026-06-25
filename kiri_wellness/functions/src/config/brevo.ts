import * as nodemailer from "nodemailer";
import * as logger from "firebase-functions/logger";

// Using SMTP relay instead of REST API eliminates Brevo's "Authorized IPs"
// restriction. SMTP uses credential-based auth, so dynamic Cloud Functions
// IPs are never blocked.
//
// Required secrets in Firebase Secret Manager:
//   BREVO_SMTP_KEY  — SMTP key (Brevo → SMTP & API → SMTP → Generate SMTP key)
//   SENDER_EMAIL    — verified sender address in Brevo (also used as SMTP login)
//   ADMIN_EMAIL     — fallback admin address when adminEmails list is empty

export const SECRET_NAMES = [
  "BREVO_SMTP_KEY",
  "BREVO_SMTP_LOGIN",
  "SENDER_EMAIL",
  "ADMIN_EMAIL",
  // WhatsApp Business Cloud API (Meta)
  "WHATSAPP_TOKEN",
  "WHATSAPP_PHONE_ID",
];

export function getSmtpKey(): string {
  return (process.env["BREVO_SMTP_KEY"] ?? "").trim();
}
// The Brevo account email used as SMTP username (may differ from sender address)
export function getSmtpLogin(): string {
  return (process.env["BREVO_SMTP_LOGIN"] ?? getSenderEmail()).trim();
}
export function getSenderEmail(): string {
  return (process.env["SENDER_EMAIL"] ?? "kirisoftcr@gmail.com").trim();
}
export function getAdminEmail(): string {
  return (process.env["ADMIN_EMAIL"] ?? "kirisoftcr@gmail.com").trim();
}

// Brevo SMTP relay — port 587, STARTTLS
// user = Brevo account email (same as sender), pass = SMTP key
function createTransport() {
  return nodemailer.createTransport({
    host: "smtp-relay.brevo.com",
    port: 587,
    secure: false,
    auth: {
      user: getSmtpLogin(),
      pass: getSmtpKey(),
    },
  });
}

export interface EmailData {
  to: Array<{ email: string; name?: string }>;
  subject: string;
  htmlContent: string;
  textContent?: string;
}

export async function sendEmail(data: EmailData): Promise<void> {
  const transport = createTransport();

  const toAddresses = data.to
    .map((r) => (r.name ? `"${r.name}" <${r.email}>` : r.email))
    .join(", ");

  await transport.sendMail({
    from: `"Kiri Wellness" <${getSenderEmail()}>`,
    to: toAddresses,
    subject: data.subject,
    html: data.htmlContent,
    ...(data.textContent ? { text: data.textContent } : {}),
  });

  logger.info("Email sent via Brevo SMTP", { to: toAddresses, subject: data.subject });
}
