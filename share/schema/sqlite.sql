CREATE TABLE upload (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  artist INTEGER NOT NULL,
  title TEXT NOT NULL,
  size INTEGER NOT NULL,
  hash TEXT UNIQUE,
  info TEXT,
  quality TEXT,
  image_url TEXT,
  server INTEGER NOT NULL,
  filename TEXT NOT NULL,
  streaming INTEGER NOT NULL DEFAULT 0,
  upload_date INTEGER NOT NULL
);

CREATE TABLE tag (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  slug TEXT UNIQUE NOT NULL
);

CREATE TABLE upload_tag (
  upload_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  PRIMARY KEY (upload_id, tag_id)
);

CREATE TABLE user_subscription (
  type TEXT CHECK(type IN ("server", "user")),
  subscriber_id INTEGER NOT NULL,
  user_id INTEGER,
  PRIMARY KEY (type, subscriber_id, user_id)
);

CREATE TABLE tag_subscription (
  type TEXT CHECK(type IN ("server", "user")),
  subscriber_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (type, subscriber_id, tag_id)
);

CREATE TABLE server (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  token TEXT UNIQUE NOT NULL,
  url TEXT NOT NULL,
  last_sync INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  everything INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE upload_fetch (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  upload_id INTEGER NOT NULL,
  server_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  timestamp INTEGER NOT NULL
);
