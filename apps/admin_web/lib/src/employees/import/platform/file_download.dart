import 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart' as platform;

/// Hands a file to the browser to save ("Download template").
typedef DownloadFile = void Function(String name, List<int> bytes, String mimeType);

/// The browser download; unsupported outside the web.
void downloadFile(String name, List<int> bytes, String mimeType) => platform.downloadFile(name, bytes, mimeType);
