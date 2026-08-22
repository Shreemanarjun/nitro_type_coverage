import 'dart:io' show ProcessInfo;

/// RSS is measurable on every native platform.
const bool rssAvailable = true;

int currentRssBytes() => ProcessInfo.currentRss;
