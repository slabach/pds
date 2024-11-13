# Base image with Node.js and Alpine Linux
FROM node:20.11-alpine3.18 as build

# Install necessary packages
RUN apk update && apk upgrade && apk add --no-cache \
    bash \
    openssh \
    wget \
    unzip \
    libc6-compat \
    ca-certificates \
    musl-locales \
    musl-locales-lang

# Set up locale (Alpine doesn't use localedef like Debian)
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Define environment variables
ARG Ngrok
ARG PDS_ADMIN_PASSWORD
ENV re=us
ENV PDS_ADMIN_PASSWORD=${PDS_ADMIN_PASSWORD}
ENV Ngrok=${Ngrok}

# Download and configure ngrok
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok.zip && rm ngrok.zip && chmod +x ./ngrok

# Create an entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'echo "Starting ngrok..."' >> /entrypoint.sh && \
    echo './ngrok config add-authtoken ${Ngrok}' >> /entrypoint.sh && \
    echo './ngrok tcp 22 --region ${re} >> /ngrok.log 2>&1 &' >> /entrypoint.sh && \
    echo 'echo "Starting SSH daemon..."' >> /entrypoint.sh && \
    echo '/usr/sbin/sshd -D' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Configure SSH
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo "root:${PDS_ADMIN_PASSWORD}" | chpasswd

# Expose necessary ports
EXPOSE 22

# Default command to execute the entrypoint script
CMD ["/bin/bash", "/entrypoint.sh"]

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

