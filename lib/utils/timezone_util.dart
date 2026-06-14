import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Utility class for timezone conversions.
class TimezoneUtil {
  static bool _initialized = false;

  /// Supported timezone identifiers mapped to their IANA location names.
  static const Map<String, String> supportedTimezones = {
    'WIB': 'Asia/Jakarta',
    'WITA': 'Asia/Makassar',
    'WIT': 'Asia/Jayapura',
    'UTC': 'UTC',
    'GMT': 'Europe/London',
    'JST': 'Asia/Tokyo',
    'SGT': 'Asia/Singapore',
    'KST': 'Asia/Seoul',
    'CST': 'Asia/Shanghai',
    'EST': 'America/New_York',
    'PST': 'America/Los_Angeles',
    'CET': 'Europe/Berlin',
    'London': 'Europe/London',
  };

  /// Initialize timezone database. Must be called before using convert/getOffset.
  static void initialize() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Converts a [DateTime] from [fromTz] timezone to [toTz] timezone.
  ///
  /// [fromTz] and [toTz] should be one of the keys in [supportedTimezones].
  /// Returns the converted [DateTime].
  /// Throws [ArgumentError] if timezone identifier is not supported.
  static DateTime convert(DateTime dt, String fromTz, String toTz) {
    initialize();

    final fromLocation = _getLocation(fromTz);
    final toLocation = _getLocation(toTz);

    // Create a TZDateTime in the source timezone
    final sourceTzDateTime = tz.TZDateTime(
      fromLocation,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );

    // Convert to the target timezone
    final targetTzDateTime = tz.TZDateTime.from(sourceTzDateTime, toLocation);

    return DateTime(
      targetTzDateTime.year,
      targetTzDateTime.month,
      targetTzDateTime.day,
      targetTzDateTime.hour,
      targetTzDateTime.minute,
      targetTzDateTime.second,
    );
  }

  /// Returns the offset in hours between [fromTz] and [toTz].
  ///
  /// A positive value means [toTz] is ahead of [fromTz].
  /// For example, getOffset('WIB', 'WITA') returns 1 (WITA is 1 hour ahead of WIB).
  ///
  /// Note: For timezones with daylight saving, the offset may vary.
  /// The offset is calculated based on the current time.
  static double getOffset(String fromTz, String toTz, {DateTime? referenceTime}) {
    initialize();

    final fromLocation = _getLocation(fromTz);
    final toLocation = _getLocation(toTz);

    final now = referenceTime ?? DateTime.now();

    final fromTzDateTime = tz.TZDateTime(
      fromLocation,
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    final toTzDateTime = tz.TZDateTime.from(fromTzDateTime, toLocation);

    // Calculate the difference in hours
    final fromOffset = fromTzDateTime.timeZoneOffset;
    final toOffset = toTzDateTime.timeZoneOffset;

    return (toOffset.inMinutes - fromOffset.inMinutes) / 60.0;
  }

  /// Returns the [tz.Location] for a given timezone abbreviation.
  static tz.Location _getLocation(String tzName) {
    final locationName = supportedTimezones[tzName];
    if (locationName == null) {
      throw ArgumentError(
        'Zona waktu "$tzName" tidak didukung. '
        'Gunakan salah satu dari: ${supportedTimezones.keys.join(", ")}',
      );
    }
    return tz.getLocation(locationName);
  }

  /// Returns a list of supported timezone display names.
  static List<String> get timezoneNames => supportedTimezones.keys.toList();
}
