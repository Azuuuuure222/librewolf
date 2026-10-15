// Use LANG environment variable to choose locale
pref("intl.locale.requested", "");

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

// Don't disable bundled extensions in the application directory.
pref("extensions.autoDisableScopes", 11);

// Linux low-memory watcher can unload inactive tabs before memory pressure becomes fatal.
pref("browser.tabs.unloadOnLowMemory", true);

// Halve periodic session-store writes on the HDD while retaining recovery.
pref("browser.sessionstore.interval", 30000);

// Avoid preloading a new-tab document before it is needed.
pref("browser.newtab.preload", false);

// Keep cache chunk memory bounded on a 4 GB system (values are KiB).
pref("browser.cache.disk.max_chunks_memory_usage", 16384);
pref("browser.cache.disk.max_priority_chunks_memory_usage", 16384);

// Fission's isolated-site pool is the relevant cap for ordinary web pages.
// Reuse at most two isolated processes per site and prelaunch only one.
pref("dom.ipc.processCount", 4);
pref("dom.ipc.processCount.webIsolated", 2);
pref("dom.ipc.processPrelaunch.fission.number", 1);

// The default is Google and we don't have API keys for it.
pref("geo.provider.network.url", "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%");
