import * as logger from "firebase-functions/logger";

// ---------------------------------------------------------------------------
// WhatsApp Business Cloud API (Meta)
//
// Secrets required in Firebase Secret Manager:
//   WHATSAPP_TOKEN     — Permanent access token from Meta Business Manager
//                        (System User token with whatsapp_business_messaging permission)
//   WHATSAPP_PHONE_ID  — WhatsApp Business Phone Number ID
//                        (Meta Business Manager → WhatsApp → Phone numbers → ID)
//
// Setup guide:
//   1. Create a Meta App at developers.facebook.com (type: Business)
//   2. Add the WhatsApp product to the app
//   3. Register a WhatsApp Business phone number
//   4. Create a System User token with the permission: whatsapp_business_messaging
//   5. Add WHATSAPP_TOKEN and WHATSAPP_PHONE_ID as Firebase secrets:
//        firebase functions:secrets:set WHATSAPP_TOKEN
//        firebase functions:secrets:set WHATSAPP_PHONE_ID
//
// NOTE on message types:
//   • Session messages  (within 24 h after the client messages you first) — any free-form text
//   • Template messages (proactive outbound) — require pre-approved templates in Meta Business Manager
//
//   For production appointment notifications (proactive), register each template in:
//   Meta Business Manager → WhatsApp → Message Templates
//   Use the template names that match the TEMPLATE_NAME constants below.
// ---------------------------------------------------------------------------

export const WHATSAPP_SECRET_NAMES = ["WHATSAPP_TOKEN", "WHATSAPP_PHONE_ID"] as const;

export function getWhatsAppToken(): string {
  return (process.env["WHATSAPP_TOKEN"] ?? "").trim();
}

export function getWhatsAppPhoneId(): string {
  return (process.env["WHATSAPP_PHONE_ID"] ?? "").trim();
}

/**
 * Returns true if WhatsApp credentials are configured and the service is enabled.
 */
export function isWhatsAppEnabled(): boolean {
  return !!(getWhatsAppToken() && getWhatsAppPhoneId());
}

/**
 * Normalizes a phone number to E.164 format for the WhatsApp API.
 * Assumes Costa Rica (+506) when no country code is present.
 *
 * @returns The phone number with country code but without leading '+',
 *          e.g. "50688001234". Returns null if the number cannot be parsed.
 */
export function normalizePhone(phone: string): string | null {
  if (!phone) return null;

  // Keep only digits and a possible leading +
  const raw = phone.replace(/\s|-|\(|\)/g, "");
  const digits = raw.replace(/\D/g, "");

  if (!digits) return null;

  // Already includes Costa Rica code (506 + 8 digits = 11 digits)
  if (digits.length === 11 && digits.startsWith("506")) {
    return digits;
  }

  // Already includes another country code (> 8 digits, starts with non-506)
  if (raw.startsWith("+") && digits.length > 8) {
    return digits;
  }

  // Plain 8-digit Costa Rica local number
  if (digits.length === 8) {
    return `506${digits}`;
  }

  // Fallback: use digits as-is if they look like an international number
  if (digits.length > 8) {
    return digits;
  }

  return null;
}

interface WhatsAppTextPayload {
  messaging_product: "whatsapp";
  to: string;
  type: "text";
  text: { body: string; preview_url?: boolean };
}

/**
 * Sends a free-form WhatsApp text message via the Meta Cloud API.
 *
 * This works within an active customer-initiated session (24 h window)
 * or against a test/sandbox phone number.
 * For proactive production notifications use sendWhatsAppTemplate().
 *
 * Failures are swallowed and logged so they never break the calling flow.
 */
export async function sendWhatsAppMessage(
  to: string,
  body: string
): Promise<void> {
  if (!isWhatsAppEnabled()) {
    logger.warn("WhatsApp not configured – skipping message", { to });
    return;
  }

  const normalizedTo = normalizePhone(to);
  if (!normalizedTo) {
    logger.warn("Invalid phone number for WhatsApp – skipping", { to });
    return;
  }

  const payload: WhatsAppTextPayload = {
    messaging_product: "whatsapp",
    to: normalizedTo,
    type: "text",
    text: { body, preview_url: false },
  };

  try {
    const response = await fetch(
      `https://graph.facebook.com/v19.0/${getWhatsAppPhoneId()}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${getWhatsAppToken()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      logger.error("WhatsApp API error", {
        status: response.status,
        to: normalizedTo,
        body: errorBody,
      });
      return;
    }

    logger.info("WhatsApp message sent", { to: normalizedTo });
  } catch (err) {
    logger.error("WhatsApp request failed", { to: normalizedTo, err });
  }
}

// ---------------------------------------------------------------------------
// Template message helper (for production proactive notifications)
// ---------------------------------------------------------------------------

export interface WhatsAppTemplateComponent {
  type: "header" | "body" | "button";
  sub_type?: "quick_reply" | "url";
  index?: string;
  parameters: Array<{ type: "text"; text: string }>;
}

/**
 * Sends a pre-approved WhatsApp template message.
 *
 * Templates must be created and approved in Meta Business Manager before use.
 * See: https://developers.facebook.com/docs/whatsapp/cloud-api/guides/send-message-templates
 *
 * Failures are swallowed and logged so they never break the calling flow.
 *
 * @returns true if the API accepted the message, false otherwise (e.g. the
 *          template is not yet approved in Meta Business Manager).
 */
export async function sendWhatsAppTemplate(
  to: string,
  templateName: string,
  languageCode: string,
  components: WhatsAppTemplateComponent[]
): Promise<boolean> {
  if (!isWhatsAppEnabled()) {
    logger.warn("WhatsApp not configured – skipping template", { to, templateName });
    return false;
  }

  const normalizedTo = normalizePhone(to);
  if (!normalizedTo) {
    logger.warn("Invalid phone number for WhatsApp template – skipping", { to });
    return false;
  }

  const payload = {
    messaging_product: "whatsapp",
    to: normalizedTo,
    type: "template",
    template: {
      name: templateName,
      language: { code: languageCode },
      components: components.length > 0 ? components : undefined,
    },
  };

  try {
    const response = await fetch(
      `https://graph.facebook.com/v19.0/${getWhatsAppPhoneId()}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${getWhatsAppToken()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      logger.error("WhatsApp template API error", {
        status: response.status,
        to: normalizedTo,
        templateName,
        body: errorBody,
      });
      return false;
    }

    logger.info("WhatsApp template sent", { to: normalizedTo, templateName });
    return true;
  } catch (err) {
    logger.error("WhatsApp template request failed", { to: normalizedTo, templateName, err });
    return false;
  }
}

/**
 * Sends a proactive notification using a pre-approved template, falling back
 * to a free-form session message if the template call fails (e.g. because the
 * template hasn't been created/approved in Meta Business Manager yet, or the
 * message is outside the 24 h session window and the template genuinely
 * doesn't exist). This keeps notifications working during the transition
 * period before templates are registered, while preferring the
 * production-safe template path once it's available.
 */
export async function sendWhatsAppWithFallback(
  to: string,
  fallbackText: string,
  templateName: string,
  languageCode: string,
  components: WhatsAppTemplateComponent[]
): Promise<void> {
  const templateSent = await sendWhatsAppTemplate(to, templateName, languageCode, components);
  if (!templateSent) {
    logger.info("Template send failed, falling back to session message", { to, templateName });
    await sendWhatsAppMessage(to, fallbackText);
  }
}
