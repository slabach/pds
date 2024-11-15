# Base image with Node.js and Alpine Linux
FROM node:20.11-alpine3.18 as build

# Additional setup for pnpm and application code
RUN npm install -g pnpm
WORKDIR /app
COPY ./service ./
RUN pnpm install --production --frozen-lockfile > /dev/null

# Final image for running the application
FROM node:20.11-alpine3.18

# Install runtime dependencies and pdsadmin tool
RUN apk add --update dumb-init bash curl openssl jq util-linux && \
    curl --silent --show-error --fail --output "/usr/local/bin/pdsadmin" "https://raw.githubusercontent.com/bluesky-social/pds/main/pdsadmin.sh" && \
    chmod +x /usr/local/bin/pdsadmin

# Avoid zombie processes and handle signal forwarding
ENTRYPOINT ["dumb-init", "--"]


WORKDIR /app
COPY --from=build /app /app

# Copy the setup script
COPY accountsetup.sh /usr/local/bin/accountsetup.sh
RUN chmod +x /usr/local/bin/accountsetup.sh

# Expose the application port
EXPOSE 3000
ENV PDS_PORT=3000
ENV NODE_ENV=production
ENV UV_USE_IO_URING=0

# Default command to run the application
CMD ["sh", "-c", "node index.js & /usr/local/bin/accountsetup.sh"]

# Metadata
LABEL org.opencontainers.image.source=https://github.com/bluesky-social/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT

