FROM alpine:3.20

# Install necessary packages
RUN apk add --no-cache openssl postgresql-client bash

# Set working directory
WORKDIR /init

# Copy scripts and migrations
COPY init.sh /init/init.sh

# Make scripts executabley
RUN chmod +x /init/*.sh

ENTRYPOINT ["/init/init.sh"]
