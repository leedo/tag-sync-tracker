All requests require a valid token in the `X-Authorization` header.

# Uploads

## GET /uploads

Get a list of uploads

### Optional
 * `since` : date
 * `page` : page number


## GET /upload/:id

Get information about an upload.


## POST /upload

Register a new upload after it has been uploaded to a server.

### Required
 * `hash` : hash of upload returned by server after upload sha1(file)
 * `sig` : returned by server after upload sha1(server_token + hash)
 * `server` : server id
 * `tags` : a list of tags
 * `title` : album title
 * `artist` : artist name
 * `size` : file size in bytes
 * `quality` : rip quality
 * `info` : description


## GET /upload/:id/tags

Get a list of tags for an upload.


## POST /upload/:id/tag

Add a tag to an existing upload.

### Required
 * `tag` : a tag slug


## DELETE /upload/:id/tag/:slug

Delete a tag from an upload


# Tags

## GET /tag/:slug/uploads

Get a list of uploads that contain a tag

### Required
 * `page` : page number


## GET /tag/:slug/servers

Get a list of servers that subscribe to the tag.

### Optional
 * `page` : page number


# Users

## GET /user/:id/uploads

Get a list of uploads for a specific user.

### Optional
 * `since` : date
 * `page` : page number


## GET /user/:id/servers

Get a list of servers that subscribe to the user.

### Optional
 * `page` : page number


# Account (user or server)

## GET /my/downloads

Get a list of matching downloads

### Optional
 * `since` : date
 * `page` : page number


## GET /my/tags

Get a list of subscribed tags

### Required
 * `page` : page number


## GET /my/users

Get a list of subscribed users

### Required
 * `page` : page number


## POST /my/tags

Subscribe to a tag

### Required
 * `tag` : tag slug


## POST /my/users

Subscribe to a user

### Required
 * `user` : id of user


## DELETE /my/users/:id

Unsubscribe from a user


## DELETE /my/tags/:slug

Unsubscribe from a tag
