/// Names of the private scratch directories DocMark creates under the OS
/// temporary root.
///
/// They are shared by the writer that creates them and the startup sweep
/// that removes them, so the two can never drift apart.
library;

/// Staging space for renderers and normalizers.
const String tempDirectoryName = 'docmark_tmp';

/// Plaintext files handed to the platform share sheet. Short-lived by
/// design: the export flow deletes each file once `share()` returns, and the
/// startup sweep catches anything a crash left behind.
const String shareDirectoryName = 'docmark_share';
