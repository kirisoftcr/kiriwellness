/**
 * Plain-text WhatsApp message templates for appointment notifications.
 *
 * WhatsApp messages support basic formatting:
 *   *text*  → bold
 *   _text_  → italic
 *   ~text~  → strikethrough
 *
 * Keep messages concise — WhatsApp renders them in a mobile chat bubble.
 *
 * For production proactive messaging (business-initiated), register equivalent
 * templates in Meta Business Manager and use sendWhatsAppTemplate() instead.
 * Template names suggested below match each function name for clarity.
 */

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function formatTime12h(time: string): string {
  const [hStr, mStr] = time.split(":");
  const h = parseInt(hStr, 10);
  const period = h < 12 ? "AM" : "PM";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${mStr.padStart(2, "0")} ${period}`;
}

// ---------------------------------------------------------------------------
// Client-facing templates
// ---------------------------------------------------------------------------

/**
 * Sent when a new appointment request is received (status = pending).
 * Meta template name suggestion: kiri_booking_pending
 */
export function whatsAppBookingPendingMessage(params: {
  clientName: string;
  serviceName: string;
  date: string;
  time: string;
  myAppointmentsUrl: string;
}): string {
  return (
    `¡Hola ${params.clientName}! 👋\n\n` +
    `Hemos recibido tu solicitud de cita en *Kiri Wellness*. 🌿\n\n` +
    `📋 *Detalles de tu cita*\n` +
    `• Servicio: ${params.serviceName}\n` +
    `• Fecha: ${params.date}\n` +
    `• Hora: ${formatTime12h(params.time)}\n\n` +
    `Tu cita está *pendiente de confirmación*. Te contactaremos pronto para confirmarla.\n\n` +
    `Puedes consultar el estado de tu cita aquí:\n${params.myAppointmentsUrl}\n\n` +
    `¡Gracias por confiar en nosotros! 💆`
  );
}

/**
 * Sent when the admin confirms an appointment (status: pending → confirmed).
 * Meta template name suggestion: kiri_booking_confirmed
 */
export function whatsAppBookingConfirmedMessage(params: {
  clientName: string;
  serviceName: string;
  date: string;
  time: string;
  myAppointmentsUrl: string;
}): string {
  return (
    `¡Hola ${params.clientName}! 🎉\n\n` +
    `Tu cita en *Kiri Wellness* ha sido *confirmada* ✅\n\n` +
    `📋 *Detalles*\n` +
    `• Servicio: ${params.serviceName}\n` +
    `• Fecha: ${params.date}\n` +
    `• Hora: ${formatTime12h(params.time)}\n\n` +
    `Puedes ver o cancelar tu cita en:\n${params.myAppointmentsUrl}\n\n` +
    `¡Te esperamos! 🌿`
  );
}

/**
 * Sent when an appointment is cancelled (by admin or by the client).
 * Meta template name suggestion: kiri_booking_cancelled
 */
export function whatsAppBookingCancelledMessage(params: {
  clientName: string;
  serviceName: string;
  date: string;
  time: string;
}): string {
  return (
    `¡Hola ${params.clientName}!\n\n` +
    `Tu cita en *Kiri Wellness* ha sido *cancelada* ❌\n\n` +
    `📋 *Detalles*\n` +
    `• Servicio: ${params.serviceName}\n` +
    `• Fecha: ${params.date}\n` +
    `• Hora: ${formatTime12h(params.time)}\n\n` +
    `Si deseas agendar una nueva cita, visítanos en:\n` +
    `https://kiriwellness.com\n\n` +
    `¡Esperamos verte pronto! 🌿`
  );
}

/**
 * Sent the day before the appointment (24-hour reminder).
 * Meta template name suggestion: kiri_appointment_reminder
 */
export function whatsAppAppointmentReminderMessage(params: {
  clientName: string;
  serviceName: string;
  date: string;
  time: string;
}): string {
  return (
    `¡Hola ${params.clientName}! ⏰\n\n` +
    `Te recordamos que *mañana* tienes una cita en *Kiri Wellness*.\n\n` +
    `📋 *Detalles*\n` +
    `• Servicio: ${params.serviceName}\n` +
    `• Fecha: ${params.date}\n` +
    `• Hora: ${formatTime12h(params.time)}\n\n` +
    `Si necesitas cancelar o reagendar, por favor contáctanos con anticipación.\n\n` +
    `¡Te esperamos! 🌿`
  );
}

/**
 * Sent when an appointment is marked as completed (thank-you message).
 * Meta template name suggestion: kiri_appointment_thankyou
 */
export function whatsAppThankYouMessage(params: {
  clientName: string;
  serviceName: string;
  myAppointmentsUrl: string;
}): string {
  return (
    `¡Hola ${params.clientName}! 🌿\n\n` +
    `¡Fue un placer recibirte hoy en *Kiri Wellness*! 💆\n\n` +
    `Esperamos que hayas disfrutado tu sesión de *${params.serviceName}* ` +
    `y que te sientas renovado/a.\n\n` +
    `Tu bienestar es nuestra prioridad. ¡Nos encanta verte por aquí!\n\n` +
    `Agenda tu próxima cita en:\n${params.myAppointmentsUrl}`
  );
}
