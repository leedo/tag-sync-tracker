1. User visits NMP3s
2. Loads upload form
3. Fills out upload form (artist, title, tags, etc)
4. Based on form, the client (js) is given a server URL to
   upload to
5. Browser uploads data to remote server
6. Server response with file hash and a signature
7. Form data is submitted to NMP3s with file hash, server id,
   and signature included
8. Upload is validated and added

User is then given a tag to put in post

e.g. [upload id="123"][/upload]

On display, the tag looks up likely servers to have that upload.
The first server is that which the file was originally uploaded to.
The rest are collected from what they are subscribed to.  E.g.  if
the upload was tagged as reggae, all the reggae servers will be
included.

When a reader views the post, javascript will ping all the servers
and ask if they have the upload. The user can choose to download
from any of the servers that say yes.
