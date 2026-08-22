/// A browser exposes no per-tab RSS to the page — `performance.memory` is a
/// Chrome-only JS-heap estimate that says nothing about the WASM module's
/// linear memory, so there is no honest number to report here.
const bool rssAvailable = false;

int currentRssBytes() =>
    throw UnsupportedError('RSS is not observable from a browser page');
