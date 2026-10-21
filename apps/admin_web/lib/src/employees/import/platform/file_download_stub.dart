/// Outside the web there is no browser to save files.
void downloadFile(String name, List<int> bytes, String mimeType) =>
    throw UnsupportedError('Downloading files is only available in the browser.');
