// iumrah Beta production tombstone — hotel catalog pricing update 050.
//
// On-device Booking/Expedia scraping is intentionally disabled. The authoritative
// hotel nightly rate is imported/refreshed by iumrah Business / HotelsWorker and
// exposed to Beta only through the fresh 48-hour public catalog cache.
//
// This path is kept as a tombstone because the repository ZIP updater overwrites
// files but does not delete legacy paths. `project.yml` also excludes it from the
// iumrahBeta target so no WebKit hotel-price bot code ships in the production app.
