# Maintenance image for moving a volume from Stalwart 0.16.27 to 1.0. Deploy it on
# the Stalwart service and it does the move, reporting in the deploy logs; then
# deploy the normal wrapper. No mail server runs while this image is up.
# STALWART_MIGRATE_ACTION=revert puts the 0.16 store back instead.
FROM stalwartlabs/stalwart-migrate:1.0.5
# Tool 1.0.5 writes a v1.0.1 store, which has to boot once on v1.0.1 before v1.0.2 can open it.
COPY --from=stalwartlabs/stalwart:v1.0.1 /usr/local/bin/stalwart /usr/local/bin/stalwart-v1.0.1
COPY --from=busybox:1.37.0-musl /bin/busybox /usr/local/bin/busybox
USER root
COPY --chmod=0755 entry.sh /entry.sh
COPY --chmod=0755 migrate.sh /migrate.sh
COPY --chmod=0755 revert.sh /revert.sh
COPY answers.toml /answers.toml
ENTRYPOINT ["/entry.sh"]
