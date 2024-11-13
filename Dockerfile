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
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/entrypoint.sh"]

WORKDIR /app
COPY --from=build /app /app

ENV PDS_ADMIN_EMAIL=admin@perfectfall.com
ENV PDS_HANDLE=perfectfall.com
ENV PDS_ADMIN_PASSWORD="${PDS_ADMIN_PASSWORD}"

# Create setup script outside of the mounted volume path
RUN echo "#!/bin/bash\n" > /usr/local/bin/entrypoint.sh && \
    echo "set -e\n" >> /usr/local/bin/entrypoint.sh && \
    echo "# Define user account details\n" >> /usr/local/bin/entrypoint.sh && \
    echo "EMAIL=\"\$PDS_ADMIN_EMAIL\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "HANDLE=\"\$PDS_ADMIN_HANDLE\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "PASSWORD=\"\$PDS_ADMIN_PASSWORD\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "# Function to create user account\n" >> /usr/local/bin/entrypoint.sh && \
    echo "create_account() {\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"Creating user account...\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  pdsadmin account create \"\$EMAIL\" \"\$HANDLE\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"User account created.\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "}\n" >> /usr/local/bin/entrypoint.sh && \
    echo "# Function to set user password\n" >> /usr/local/bin/entrypoint.sh && \
    echo "set_password() {\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"Setting password for user...\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"\$PASSWORD\" | pdsadmin set-password \"\$HANDLE\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"Password set successfully.\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "}\n" >> /usr/local/bin/entrypoint.sh && \
    echo "# Check if the account already exists\n" >> /usr/local/bin/entrypoint.sh && \
    echo "if pdsadmin account list | grep -q \"\$HANDLE\"; then\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  echo \"User account already exists.\"\n" >> /usr/local/bin/entrypoint.sh && \
    echo "else\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  create_account\n" >> /usr/local/bin/entrypoint.sh && \
    echo "  set_password\n" >> /usr/local/bin/entrypoint.sh && \
    echo "fi\n" >> /usr/local/bin/entrypoint.sh && \
    echo "# Start the application\n" >> /usr/local/bin/entrypoint.sh && \
    echo "exec \"\$@\"\n" >> /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Expose the application port
EXPOSE 3000
ENV PDS_PORT=3000
ENV NODE_ENV=production
ENV UV_USE_IO_URING=0

# Default command to run the application
CMD ["node", "--enable-source-maps", "index.js"]

# Metadata
LABEL org.opencontainers.image.source=https://github.com/bluesky-social/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT

