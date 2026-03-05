import 'package:flutter_test/flutter_test.dart';

class DoctorSchedule {
  // map of date (yyyy-mm-dd) -> available time slots (HH:mm)
  final Map<String, List<String>> slots;
  const DoctorSchedule(this.slots);
}

class PatientPreference {
  final String date; // yyyy-mm-dd
  final String time; // HH:mm
  const PatientPreference(this.date, this.time);
}

class Appointment {
  final String doctorId;
  final String patientId;
  final String date; // yyyy-mm-dd
  final String time; // HH:mm
  const Appointment(this.doctorId, this.patientId, this.date, this.time);
}

Appointment? makeAppointment({
  required String doctorId,
  required String patientId,
  required DoctorSchedule schedule,
  required PatientPreference preference,
}) {
  final daySlots = schedule.slots[preference.date] ?? const [];
  if (daySlots.contains(preference.time)) {
    return Appointment(doctorId, patientId, preference.date, preference.time);
  }
  // If exact time not available, try nearest slot on same day
  if (daySlots.isNotEmpty) {
    return Appointment(doctorId, patientId, preference.date, daySlots.first);
  }
  return null;
}

Appointment? changeAppointment({
  required Appointment current,
  required String newDate,
  required String newTime,
  required DoctorSchedule schedule,
}) {
  final daySlots = schedule.slots[newDate] ?? const [];
  if (daySlots.contains(newTime)) {
    return Appointment(current.doctorId, current.patientId, newDate, newTime);
  }
  return null;
}

void main() {
  group('Integration: Scheduling Nutritionist Consultation', () {
    test('Make Appointment: doctor schedule + patient preferred date/time', () {
      final schedule = DoctorSchedule({
        '2026-03-01': ['09:00', '10:00'],
        '2026-03-02': ['14:00'],
      });
      final pref = PatientPreference('2026-03-01', '10:00');
      final appt = makeAppointment(
        doctorId: 'nut_1',
        patientId: 'user_1',
        schedule: schedule,
        preference: pref,
      );
      expect(appt, isNotNull);
      expect(appt!.date, '2026-03-01');
      expect(appt.time, '10:00');
    });

    test('Change Appointment booking: select new date/time shows final selection', () {
      final schedule = DoctorSchedule({
        '2026-03-05': ['11:00', '11:30'],
      });
      final current = Appointment('nut_1', 'user_1', '2026-03-01', '10:00');
      final updated = changeAppointment(
        current: current,
        newDate: '2026-03-05',
        newTime: '11:30',
        schedule: schedule,
      );
      expect(updated, isNotNull);
      expect(updated!.date, '2026-03-05');
      expect(updated.time, '11:30');
    });
  });
}

