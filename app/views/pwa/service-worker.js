// Deliberately caches nothing: this is a live reference site whose value is
// current data, and a stale HTML cache would break Turbo Drive navigation.
// It exists so the app is installable (Chrome requires a fetch listener) and
// so /service-worker resolves instead of 404ing on every page load.
self.addEventListener("fetch", () => {})
