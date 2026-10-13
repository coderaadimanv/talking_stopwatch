import 'dart:io';

/// Removes a test's scratch directory, allowing for a save still landing in it.
///
/// The app saves by writing a temporary file and renaming it, and nothing in
/// it awaits that — a controller's change returns before the write finishes,
/// which is correct for an app and awkward for a test. So a teardown deleting
/// the directory can race a file being created inside it, and the failure it
/// gets is `Directory not empty`, which says nothing about why.
///
/// One short retry, rather than plumbing a Future out through the notifier
/// purely so that teardowns can wait on it.
Future<void> removeTemp(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } on FileSystemException {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
