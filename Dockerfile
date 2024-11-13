FROM node:20.11-alpine3.18 as build

RUN apk update && apk upgrade && apk add --no-cache \
    bash \
    openssh \
    wget \
    unzip \
    libc6-compat \
    ca-certificates \
    musl-locales \
    musl-locales-lang

# Set up locale (Alpine does not use `localedef` like Debian)
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Set environment variables
ARG Ngrok
ARG PDS_ADMIN_PASSWORD
ARG re
ENV re=${re}
ENV PDS_ADMIN_PASSWORD=${PDS_ADMIN_PASSWORD}
ENV Ngrok=${Ngrok}

# Download and configure ngrok
RUN wget -q -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip && rm ngrok.zip
RUN echo "./ngrok config add-authtoken ${Ngrok} &&" >>/1.sh
RUN echo "./ngrok tcp 22 --region ${re} &>/dev/null &" >>/1.sh

# Configure SSH
RUN mkdir -p /run/sshd
RUN echo '/usr/sbin/sshd -D' >>/1.sh
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo "root:${PDS_ADMIN_PASSWORD}" | chpasswd

# Ensure script is executable
RUN chmod 755 /1.sh

# Expose ports
EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

# Run the script
CMD ["/bin/bash", "/1.sh"]

RUN npm install -g pnpm

# Move files into the image and install
WORKDIR /app
COPY ./service ./
RUN pnpm install --production --frozen-lockfile > /dev/null

# Uses assets from build stage to reduce build size
FROM node:20.11-alpine3.18

# Install required packages and pdsadmin tool
RUN apk add --update dumb-init bash curl openssl jq util-linux && \
  curl --silent --show-error --fail --output "/usr/local/bin/pdsadmin" "https://raw.githubusercontent.com/bluesky-social/pds/main/pdsadmin.sh" && \
  chmod +x /usr/local/bin/pdsadmin

# Avoid zombie processes, handle signal forwarding
ENTRYPOINT ["dumb-init", "--"]

WORKDIR /app
COPY --from=build /app /app

EXPOSE 3000
ENV PDS_PORT=3000
ENV NODE_ENV=production
# potential perf issues w/ io_uring on this version of node
ENV UV_USE_IO_URING=0

CMD ["node", "--enable-source-maps", "index.js"]

LABEL org.opencontainers.image.source=https://github.com/bluesky-social/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
