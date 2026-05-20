/**
 * Returns the HTML body for a verification code email (Mis Citas portal).
 */
export function verificationCodeHtml(params: {
  clientName: string;
  code: string;
}): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Código de verificación – Kiri Wellness</title>
</head>
<body style="margin:0;padding:0;background:#F9F6F2;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9F6F2;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:#7B9E87;padding:36px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;letter-spacing:2px;font-family:Georgia,serif;">KIRI</h1>
              <p style="margin:4px 0 0;color:#d4ead9;font-size:13px;letter-spacing:4px;">WELLNESS</p>
              <p style="margin:6px 0 0;color:#c0e0c8;font-size:12px;font-style:italic;">· tu pausa perfecta ·</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 32px;">
              <h2 style="margin:0 0 12px;color:#3d3d3d;font-size:20px;">Tu código de verificación</h2>
              <p style="margin:0 0 28px;color:#666;font-size:15px;">Hola <strong>${params.clientName}</strong>, usa el código de abajo para acceder a tus citas en Kiri Wellness.</p>

              <!-- Code box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td align="center">
                    <div style="display:inline-block;background:#F0F7F2;border:2px solid #7B9E87;border-radius:12px;padding:24px 40px;text-align:center;">
                      <p style="margin:0 0 6px;color:#7B9E87;font-size:11px;text-transform:uppercase;letter-spacing:2px;font-weight:600;">Código de acceso</p>
                      <p style="margin:0;color:#2D2D2D;font-size:40px;font-weight:700;letter-spacing:10px;font-family:monospace;">${params.code}</p>
                      <p style="margin:8px 0 0;color:#999;font-size:12px;">Válido por 15 minutos</p>
                    </div>
                  </td>
                </tr>
              </table>

              <p style="margin:0;color:#888;font-size:13px;line-height:1.6;">
                Si no solicitaste este código, puedes ignorar este correo. Nadie más tiene acceso a tu cuenta.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#F0F7F2;padding:20px 40px;text-align:center;border-top:1px solid #e0e0e0;">
              <p style="margin:0;color:#888;font-size:12px;">© ${new Date().getFullYear()} Kiri Wellness · Costa Rica</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Converts "HH:mm" 24h to "h:mm AM/PM".
 */
function formatTime12h(time: string): string {
  const [hStr, mStr] = time.split(":");
  const h = parseInt(hStr, 10);
  const period = h < 12 ? "AM" : "PM";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${mStr.padStart(2, "0")} ${period}`;
}

/**
 * Returns the HTML body for a booking confirmation email sent to the client.
 */
export function bookingConfirmationHtml(params: {
  clientName: string;
  clientCode: string;
  serviceName: string;
  date: string;
  time: string;
  notes?: string;
  myAppointmentsUrl: string;
}): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Solicitud de cita – Kiri Wellness</title>
</head>
<body style="margin:0;padding:0;background:#F9F6F2;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9F6F2;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:#7B9E87;padding:36px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;letter-spacing:1px;">Kiri Wellness</h1>
              <p style="margin:6px 0 0;color:#d4ead9;font-size:14px;">Masajes &amp; Bienestar</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:36px 40px;">
              <h2 style="margin:0 0 8px;color:#3d3d3d;font-size:20px;">📋 Confirma tu cita</h2>
              <p style="margin:0 0 24px;color:#666;font-size:15px;">Hola <strong>${params.clientName}</strong>, hemos recibido tu solicitud de cita. Revisa los detalles a continuación y confírmala cuando estés listo.</p>

              <!-- KW Code Badge -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td style="background:#F0F7F2;border:1.5px solid #7B9E87;border-radius:8px;padding:16px 20px;">
                    <p style="margin:0 0 4px;color:#7B9E87;font-size:11px;text-transform:uppercase;letter-spacing:1px;font-weight:600;">Tu código de cliente</p>
                    <p style="margin:0;color:#3d3d3d;font-size:26px;font-weight:700;letter-spacing:4px;">${params.clientCode}</p>
                    <p style="margin:4px 0 0;color:#888;font-size:12px;">Guarda este código para futuras referencias.</p>
                  </td>
                </tr>
              </table>

              <!-- Appointment Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e8e8e8;border-radius:8px;overflow:hidden;margin-bottom:28px;">
                <tr style="background:#f9f9f9;">
                  <td style="padding:12px 16px;color:#888;font-size:13px;width:40%;">Servicio</td>
                  <td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;">${params.serviceName}</td>
                </tr>
                <tr>
                  <td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Fecha</td>
                  <td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${params.date}</td>
                </tr>
                <tr style="background:#f9f9f9;">
                  <td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Hora</td>
                  <td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${formatTime12h(params.time)}</td>
                </tr>
                ${
                  params.notes
                    ? `<tr>
                  <td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Notas</td>
                  <td style="padding:12px 16px;color:#3d3d3d;font-size:13px;border-top:1px solid #e8e8e8;">${params.notes}</td>
                </tr>`
                    : ""
                }
              </table>

              <p style="margin:0 0 24px;color:#666;font-size:14px;line-height:1.6;">
                Tu cita está <strong>pendiente de confirmación</strong>. Te contactaremos pronto para confirmar el horario. ¡Gracias por confiar en nosotros!
              </p>

              <!-- Action buttons -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td align="center">
                    <a href="${params.myAppointmentsUrl}" style="display:inline-block;background:#7B9E87;color:#ffffff;text-decoration:none;padding:14px 32px;border-radius:8px;font-size:15px;font-weight:600;margin-right:12px;">📅 Ver mis citas</a>
                    <a href="${params.myAppointmentsUrl}" style="display:inline-block;background:#ffffff;color:#c0392b;text-decoration:none;padding:14px 32px;border-radius:8px;font-size:15px;font-weight:600;border:2px solid #c0392b;">✕ Cancelar cita</a>
                  </td>
                </tr>
                <tr><td align="center" style="padding-top:10px;"><p style="margin:0;color:#aaa;font-size:11px;">Se te pedirá verificar tu correo para acceder.</p></td></tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:#F0F7F2;padding:20px 40px;text-align:center;border-top:1px solid #e0e0e0;">
              <p style="margin:0;color:#888;font-size:12px;">© ${new Date().getFullYear()} Kiri Wellness · Costa Rica</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Returns the HTML body for an admin notification email when a new booking is made.
 */
/**
 * Returns the HTML body for a booking confirmation sent to the client when
 * the admin explicitly confirms their appointment.
 */
export function appointmentConfirmedClientHtml(params: {
  clientName: string;
  clientCode: string;
  serviceName: string;
  date: string;
  time: string;
  notes?: string;
  myAppointmentsUrl: string;
  googleCalendarUrl: string;
}): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Cita confirmada – Kiri Wellness</title>
</head>
<body style="margin:0;padding:0;background:#F9F6F2;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9F6F2;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:#2E7D32;padding:36px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;letter-spacing:1px;">Kiri Wellness</h1>
              <p style="margin:6px 0 0;color:#a5d6a7;font-size:14px;">Masajes &amp; Bienestar</p>
            </td>
          </tr>
          <tr>
            <td style="padding:36px 40px;">
              <h2 style="margin:0 0 8px;color:#2E7D32;font-size:22px;">✅ ¡Tu cita fue confirmada!</h2>
              <p style="margin:0 0 24px;color:#666;font-size:15px;">Hola <strong>${params.clientName}</strong>, nuestro equipo ha confirmado tu cita. ¡Te esperamos!</p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td style="background:#F0F7F2;border:1.5px solid #7B9E87;border-radius:8px;padding:16px 20px;">
                    <p style="margin:0 0 4px;color:#7B9E87;font-size:11px;text-transform:uppercase;letter-spacing:1px;font-weight:600;">Tu código de cliente</p>
                    <p style="margin:0;color:#2D2D2D;font-size:22px;font-weight:700;letter-spacing:3px;">${params.clientCode}</p>
                  </td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e8e8e8;border-radius:8px;overflow:hidden;margin-bottom:28px;">
                <tr><td style="padding:12px 16px;color:#888;font-size:13px;width:40%;">Servicio</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;">${params.serviceName}</td></tr>
                <tr style="background:#f9f9f9;"><td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Fecha</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${params.date}</td></tr>
                <tr><td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Hora</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${formatTime12h(params.time)}</td></tr>
                ${params.notes ? `<tr style="background:#f9f9f9;"><td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Notas</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;border-top:1px solid #e8e8e8;">${params.notes}</td></tr>` : ""}
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                <tr>
                  <td align="center">
                    <a href="${params.googleCalendarUrl}" style="display:inline-block;background:#4285F4;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 28px;border-radius:8px;margin-bottom:8px;">📅 Agregar a Google Calendar</a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:8px;">
                    <a href="${params.myAppointmentsUrl}" style="display:inline-block;background:#7B9E87;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 28px;border-radius:8px;">Ver mis citas</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr><td style="background:#F0F7F2;padding:20px 40px;text-align:center;border-top:1px solid #e0e0e0;"><p style="margin:0;color:#888;font-size:12px;">© ${new Date().getFullYear()} Kiri Wellness · Costa Rica</p></td></tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function adminBookingNotificationHtml(params: {
  clientName: string;
  clientLastName: string;
  clientCode: string;
  clientPhone: string;
  clientEmail: string;
  serviceName: string;
  date: string;
  time: string;
  notes?: string;
  isNewClient: boolean;
  event?: "requested" | "confirmed" | "cancelled";
}): string {
  const isConfirmed = params.event === "confirmed";
  const isCancelled = params.event === "cancelled";
  const headerBg = isConfirmed ? "#2E7D32" : isCancelled ? "#b71c1c" : "#D4A5A5";
  const headerIcon = isConfirmed ? "✅" : isCancelled ? "❌" : "🔔";
  const headerTitle = isConfirmed ? "Cita confirmada" : isCancelled ? "Cita cancelada" : "Nueva cita agendada";
  return `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8" /><title>${headerTitle} – Kiri Wellness</title></head>
<body style="margin:0;padding:0;background:#F9F6F2;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9F6F2;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:${headerBg};padding:28px 40px;">
              <h2 style="margin:0;color:#ffffff;font-size:20px;">${headerIcon} ${headerTitle}</h2>
              <p style="margin:4px 0 0;color:#fff;font-size:13px;opacity:0.85;">Panel Administrador – Kiri Wellness</p>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 40px;">
              ${
                params.isNewClient
                  ? `<p style="margin:0 0 20px;background:#FFF3CD;border:1px solid #FFEAA7;border-radius:6px;padding:10px 14px;color:#856404;font-size:13px;">⭐ <strong>Cliente nuevo</strong> — código asignado: <strong>${params.clientCode}</strong></p>`
                  : `<p style="margin:0 0 20px;background:#E8F4FD;border:1px solid #BEE3F8;border-radius:6px;padding:10px 14px;color:#2C5282;font-size:13px;">🔄 <strong>Cliente existente</strong> — código: <strong>${params.clientCode}</strong></p>`
              }

              <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e8e8e8;border-radius:8px;overflow:hidden;margin-bottom:20px;">
                <tr style="background:#f9f9f9;"><td colspan="2" style="padding:10px 16px;color:#7B9E87;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1px;">Datos del Cliente</td></tr>
                <tr><td style="padding:10px 16px;color:#888;font-size:13px;width:35%;">Nombre</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;font-weight:600;">${params.clientName} ${params.clientLastName}</td></tr>
                <tr style="background:#f9f9f9;"><td style="padding:10px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Teléfono</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;border-top:1px solid #e8e8e8;">${params.clientPhone}</td></tr>
                <tr><td style="padding:10px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Email</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;border-top:1px solid #e8e8e8;">${params.clientEmail || "—"}</td></tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e8e8e8;border-radius:8px;overflow:hidden;">
                <tr style="background:#f9f9f9;"><td colspan="2" style="padding:10px 16px;color:#D4A5A5;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1px;">Detalles de la Cita</td></tr>
                <tr><td style="padding:10px 16px;color:#888;font-size:13px;width:35%;">Servicio</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;font-weight:600;">${params.serviceName}</td></tr>
                <tr style="background:#f9f9f9;"><td style="padding:10px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Fecha</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${params.date}</td></tr>
                <tr><td style="padding:10px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Hora</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${formatTime12h(params.time)}</td></tr>
                ${
                  params.notes
                    ? `<tr style="background:#f9f9f9;"><td style="padding:10px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Notas</td><td style="padding:10px 16px;color:#3d3d3d;font-size:13px;border-top:1px solid #e8e8e8;">${params.notes}</td></tr>`
                    : ""
                }
              </table>
            </td>
          </tr>
          <tr><td style="background:#F0F7F2;padding:16px 40px;text-align:center;border-top:1px solid #e0e0e0;"><p style="margin:0;color:#888;font-size:12px;">Kiri Wellness Admin · ${new Date().getFullYear()}</p></td></tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Returns the HTML body for a 24-hour appointment reminder.
 */
export function appointmentReminderHtml(params: {
  clientName: string;
  serviceName: string;
  date: string;
  time: string;
}): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8" /><title>Recordatorio de cita – Kiri Wellness</title></head>
<body style="margin:0;padding:0;background:#F9F6F2;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9F6F2;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:#7B9E87;padding:36px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;letter-spacing:1px;">Kiri Wellness</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:36px 40px;">
              <h2 style="margin:0 0 8px;color:#3d3d3d;font-size:20px;">⏰ Recordatorio de cita</h2>
              <p style="margin:0 0 24px;color:#666;font-size:15px;">Hola <strong>${params.clientName}</strong>, te recordamos que mañana tienes una cita con nosotros.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e8e8e8;border-radius:8px;overflow:hidden;margin-bottom:24px;">
                <tr><td style="padding:12px 16px;color:#888;font-size:13px;width:40%;">Servicio</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;">${params.serviceName}</td></tr>
                <tr style="background:#f9f9f9;"><td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Fecha</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${params.date}</td></tr>
                <tr><td style="padding:12px 16px;color:#888;font-size:13px;border-top:1px solid #e8e8e8;">Hora</td><td style="padding:12px 16px;color:#3d3d3d;font-size:13px;font-weight:600;border-top:1px solid #e8e8e8;">${formatTime12h(params.time)}</td></tr>
              </table>
              <p style="margin:0;color:#666;font-size:14px;line-height:1.6;">¡Te esperamos! Si necesitas cancelar o reagendar, por favor contáctanos con anticipación. 🌿</p>
            </td>
          </tr>
          <tr><td style="background:#F0F7F2;padding:20px 40px;text-align:center;border-top:1px solid #e0e0e0;"><p style="margin:0;color:#888;font-size:12px;">© ${new Date().getFullYear()} Kiri Wellness · Costa Rica</p></td></tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}
