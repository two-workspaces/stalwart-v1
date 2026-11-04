FROM stalwartlabs/stalwart:v1.0.3

# Runs as root so the root-owned Railway volume needs no ownership dance, and
# so Stalwart can bind the privileged mail ports (25/465/993/...).
USER root

COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
# Setting ENTRYPOINT clears the upstream CMD — restore it.
CMD ["--config", "/etc/stalwart/config.json"]
