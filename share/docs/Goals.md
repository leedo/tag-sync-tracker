# Tracker (runs on NMP3s)

## Goals
 * Track user and server subscriptions (tracker-api)
 * Track basic metadata on uploads (tracker-api)
 * Enable servers and client to discover new uploads based on metadata (tracker-api)
 * Give servers and client a list of suggested servers to ask for a download (tracker-api)
   * One will be server data was initially uploaded to
   * Others will be guesses based on metadata (tags, user)

## Non-goals
 * Track which server upload is on
 * Be a comprehensive music database
 * Deal with upload quality (e.g. trumping)


# Servers (runs on many user contributed servers)

## Goals
  * Discover recent uploads from tracker based on metadata (tracker-api)
  * Find out from tracker which servers might have the uploads (tracker-api)
  * Mirror uploads from other servers (server-api)

## Unsure
 * List of uploads for browsing? (breaks current boundaries)

## Non-goals
 * Track metadata


# Client (browsers)

## Goals
  * Display recent uploads based on user subscriptions (tracker-api)
  * If users chooses to download
    * Find out from tracker which servers might have the download (tracker-api)
    * Download files (server-api)
