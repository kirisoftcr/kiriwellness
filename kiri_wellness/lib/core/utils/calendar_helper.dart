// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// URL builder
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a Google Calendar "Add Event" URL pre-filled with the appointment.
String buildGoogleCalendarUrl({
  required String serviceName,
  required String date, // "YYYY-MM-DD"
  required String time, // "HH:mm"
  required int durationMin,
}) {
  try {
    final parts = date.split('-');
    final tParts = time.split(':');
    final start = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(tParts[0]),
      int.parse(tParts[1]),
    );
    final end = start.add(Duration(minutes: durationMin));
    final fmt = DateFormat("yyyyMMdd'T'HHmmss");
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Kiri Wellness – $serviceName',
      'dates': '${fmt.format(start)}/${fmt.format(end)}',
      'details': 'Servicio: $serviceName en Kiri Wellness',
      'location': 'Kiri Wellness, Costa Rica',
    }).toString();
  } catch (_) {
    return 'https://calendar.google.com';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ICS download (web-only)
// ─────────────────────────────────────────────────────────────────────────────

/// Downloads an `.ics` file so the user can import it into Apple Calendar /
/// Outlook / any calendar that supports the iCalendar format.
void downloadIcs({
  required String id,
  required String serviceName,
  required String date,
  required String time,
  required int durationMin,
}) {
  try {
    final parts = date.split('-');
    final tParts = time.split(':');
    final start = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(tParts[0]),
      int.parse(tParts[1]),
    );
    final end = start.add(Duration(minutes: durationMin));
    final fmt = DateFormat("yyyyMMdd'T'HHmmss");
    final stamp = DateFormat("yyyyMMdd'T'HHmmss").format(DateTime.now());

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Kiri Wellness//ES',
      'BEGIN:VEVENT',
      'UID:$id@kiriwellness.com',
      'DTSTAMP:${stamp}Z',
      'DTSTART:${fmt.format(start)}',
      'DTEND:${fmt.format(end)}',
      'SUMMARY:Kiri Wellness – $serviceName',
      'DESCRIPTION:Servicio: $serviceName en Kiri Wellness',
      'LOCATION:Kiri Wellness\\, Costa Rica',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    // ignore: avoid_web_libraries_in_flutter
    final blob = html.Blob([ics], 'text/calendar;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'cita-kiri-wellness.ics')
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a modal bottom sheet with calendar sync options.
void showAddToCalendar(
  BuildContext context, {
  required String id,
  required String serviceName,
  required String date,
  required String time,
  required int durationMin,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Agregar al calendario',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            serviceName,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          // Google Calendar
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today,
                  color: Color(0xFF4285F4), size: 20),
            ),
            title: const Text('Google Calendar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Android · Web',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.open_in_new,
                size: 16, color: AppTheme.textSecondary),
            onTap: () async {
              Navigator.pop(context);
              final url = buildGoogleCalendarUrl(
                serviceName: serviceName,
                date: date,
                time: time,
                durationMin: durationMin,
              );
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
          ),
          const Divider(height: 1),
          // ICS download
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.download_outlined,
                  color: Colors.grey.shade700, size: 20),
            ),
            title: const Text('Descargar .ics',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Apple Calendar · Outlook',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.download,
                size: 16, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.pop(context);
              downloadIcs(
                id: id,
                serviceName: serviceName,
                date: date,
                time: time,
                durationMin: durationMin,
              );
            },
          ),
        ],
      ),
    ),
  );
}
