# Moving a Railway copy from Stalwart 0.16 to 1.0

Stalwart 1.0 can't open a 0.16 store. Don't deploy 1.0 on a 0.16 volume by hand: an unguarded 1.0 server
writes to the store before it refuses, and recent mail was lost that way in testing. The wrapper in this
repo refuses to start on a 0.16 store, so a mistake here costs an outage rather than mail.

The `migrate` image copies the store into a new 1.0 store on the same volume, then switches over. The mail
server is down for the whole move.

## Before you start

- Run Stalwart **0.16.27** exactly. The startup log shows the version, and the migration tool won't accept
  anything else.
- Check the volume has room for a second copy of the store. The old one is kept until you remove it.
- Take a volume backup in Railway.
- Install the [Railway CLI](https://docs.railway.com/guides/cli) and run `railway login`.

## What changes for your users

- OAuth tokens aren't carried over, so everyone signs in again. IMAP, SMTP and app passwords keep working.
- Unregistered OAuth clients are refused on 1.0. After the move, add yours under Directory → OAuth Clients
  and list every scope it asks for. The JMAP Webmail template needs mail, contacts, calendars, files and
  security.
- CalDAV, CardDAV and WebDAV clients download their data once more.

## Moving

```sh
git clone https://github.com/two-workspaces/stalwart-v1
cd stalwart-v1
railway link     # pick your project and environment
```

1. In the Railway dashboard, open the service's Settings → Source and disconnect the old repo. Do this
   first. While it's connected, any variable change redeploys 0.16 from that repo, and on a 1.0 store that
   crash-loops. In testing, the 1.0 wrapper no longer came up healthy on that store afterwards, so you'd be
   restoring your volume backup. Railway may still remember the repo as the template's source, so don't
   accept an update from `two-workspaces/stalwart` afterwards either.

2. Deploy the migration image. It starts the move as soon as it's up.

   ```sh
   railway up migrate --path-as-root --service stalwart --detach
   railway logs --service stalwart
   ```

   Wait for `done: deploy the normal wrapper now.` If you see `migration failed`, nothing was switched:
   skip to [Going back](#going-back), step 2, and your 0.16 server returns with its store as it was.

3. Deploy the wrapper from the repo root.

   ```sh
   railway up --service stalwart --detach
   railway logs --service stalwart
   ```

   Check your mail, and sign in to `/admin` as usual. To confirm the version, this lists
   `urn:stalwart:oauth:scope:security` from 1.0.3 on:

   ```sh
   curl -s https://YOUR-DOMAIN/.well-known/oauth-authorization-server
   ```

4. Give the default roles the permissions added since 1.0.0: add the variable
   `STALWART_UPDATE_ROLE_PERMISSIONS=true`, let the service restart, then remove the variable.

Once you're sure, free the space:

```sh
railway ssh --service stalwart -- rm -rf /data/data-0.16 /data/etc-0.16
```

## Going back

Mail that 1.0 received isn't in the 0.16 store, so this only suits the time right after the move.

1. Skip this step if the migration failed. Otherwise, in the service's variables set
   `STALWART_MIGRATE_ACTION=revert`, deploy the migration image as above, and wait for `done: roll the service
   back`.
2. In the dashboard's Deployments list, roll back to your last 0.16.27 deployment.
3. Remove `STALWART_MIGRATE_ACTION`, without deploying again.

## How this was tested

Rehearsed with these commands on a throwaway copy of the template: a small 0.16.27 store with one message,
moved to 1.0.3 with the old repo disconnected first. The message was there after the move, after the role
step and after going back. Not tested: a large store, calendars and contacts, or real SMTP delivery. Check
those first if you depend on them.
