# Blood Bank Management System - container image
#
# The base image is pinned to an explicit version. `nginx:latest` is not a fixed
# version: it is whatever release happens to be tagged newest on Docker Hub at the
# moment the image is built, so an image that works on one machine can fail to build
# on a different one with no change to this file. Pinning means everyone, every
# time, gets the same Nginx.

FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Blood Bank Management System" \
      org.opencontainers.image.description="Static front end for the Blood Bank Management System" \
      org.opencontainers.image.vendor="skit-devops-2026"

# Copy the application explicitly rather than `COPY . .`, so an accidental file in the
# working tree cannot quietly become part of the published image.
COPY index.html /usr/share/nginx/html/index.html
COPY css/ /usr/share/nginx/html/css/

# The test suite is shipped inside the image on purpose. CI runs it against the exact
# artefact that will be deployed, rather than against a copy of the source in a
# different environment, which is the point of testing in the container.
COPY tests/ /opt/bloodbank/tests/

EXPOSE 80

# Alpine ships BusyBox wget, so this needs no extra packages.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
