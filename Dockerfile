# Build Stage: Compile and install libpki and OpenCA OCSPD
FROM ubuntu:20.04 AS build-stage

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
        curl \
        gcc \
        libicu-dev \
        libldap-dev \
        libssl-dev \
        libxml2-dev \
        make \
        net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download, patch, build, and install libpki
RUN curl -o libpki.tar.gz https://codeload.github.com/openca/libpki/tar.gz/refs/tags/v0.9.2 && \
    tar -xzf libpki.tar.gz && \
    cd libpki-0.9.2 && \
    sed -i 's/strncpy( ret, my_search, strlen(my_search) );/strcpy( ret, my_search );/' src/pki_config.c && \
    ./configure && \
    make && \
    make install && \
    ln -s /usr/lib64/libpki.so.92 /usr/lib/libpki.so.92 && \
    cd / && \
    rm -rf libpki.tar.gz libpki-0.9.2

# Download, build, and install OpenCA OCSPD
RUN curl -o openca-ocspd.tar.gz https://codeload.github.com/openca/openca-ocspd/tar.gz/refs/tags/v3.1.3 && \
    tar -xzf openca-ocspd.tar.gz && \
    cd openca-ocspd-3.1.3 && \
    ./configure --prefix=/usr/local/ocspd && \
    make && \
    make install && \
    cd / && \
    rm -rf openca-ocspd.tar.gz openca-ocspd-3.1.3

# Runtime Stage: Copy the necessary binaries and configurations into a lightweight image
FROM ubuntu:20.04 AS runtime

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y \
        libicu-dev \
        libldap-dev \
        libssl-dev \
        libxml2-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy compiled binaries and configurations from the build stage
COPY --from=build-stage /usr/local/ocspd /usr/local/ocspd
COPY --from=build-stage /usr/lib/libpki.so.92 /usr/lib/libpki.so.92

# Copy custom configuration files
COPY ca.xml /usr/local/ocspd/etc/ocspd/ca.d/ca.xml
COPY ocspd.xml /usr/local/ocspd/etc/ocspd/ocspd.xml
COPY token.xml /usr/local/ocspd/etc/ocspd/pki/token.d/token.xml

# Set up user and permissions
RUN useradd ocspd && \
    chown -R ocspd:ocspd /usr/local/ocspd/

# # Switch to the non-root user for security
USER ocspd

# Entry point for OpenCA OCSPD
ENTRYPOINT [ "/usr/local/ocspd/sbin/ocspd", "-stdout", "-c", "/usr/local/ocspd/etc/ocspd/ocspd.xml" ]