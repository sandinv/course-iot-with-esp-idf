# Settings
ARG DEBIAN_VERSION=stable-20241223-slim
ARG IDF_VERSION=5.4.1

# Optional features (set via build args)
ARG INSTALL_MOSQUITTO=false
ARG MOSQUITTO_USERNAME="iot"
ARG MOSQUITTO_PASSWORD="mosquitto"
ARG MOSQUITTO_VERSION=2.0.20

#-------------------------------------------------------------------------------
# Base Image and Dependencies

FROM debian:${DEBIAN_VERSION}

# Redeclare arguments after FROM
ARG TARGETARCH
ARG IDF_VERSION
ARG INSTALL_MOSQUITTO
ARG MOSQUITTO_USERNAME
ARG MOSQUITTO_PASSWORD
ARG MOSQUITTO_VERSION

# Set default shell during Docker image build to bash
SHELL ["/bin/bash", "-c"]

# Check if the target architecture is supported
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        echo "Architecture $TARGETARCH is supported."; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; \
        exit 1; \
    fi

# Set non-interactive frontend for apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get -y update && \
    apt-get install --no-install-recommends -y \
    wget \
    curl \
    git \
    locales \
    python3 \
    python3-pip \
    python3-venv \
    xz-utils \
    flex \
    bison \
    gperf \
    cmake \
    build-essential \
    ninja-build \
    ccache \
    libffi-dev \
    libgcrypt20 \
    libglib2.0-0 \
    libpixman-1-0 \
    libsdl2-2.0-0 \
    libslirp0 \
    libssl-dev \
    libusb-1.0-0

# Clean up
RUN apt-get clean -y && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/*

# Set up directories
RUN mkdir -p /workspace/apps && \
    mkdir -p /opt/toolchains

#-------------------------------------------------------------------------------
# ESP-IDF

ENV IDF_VERSION=${IDF_VERSION}
ENV IDF_TOOLS_PATH=/opt/toolchains/espressif

# Download and install ESP-IDF
RUN cd /opt/toolchains && \
    git clone --recursive --branch v${IDF_VERSION} --depth 1 https://github.com/espressif/esp-idf.git && \
    cd esp-idf && \
    ./install.sh all

# Get compiler path for IntelliSense
RUN bash && \
    . /opt/toolchains/esp-idf/export.sh && \
    echo "IDF_COMPILER_PATH=$(whereis xtensa-esp-elf-gcc | awk '{print $2}')" >> /etc/environment && \
    exit

# Copy C/C++ IntelliSense configuration
RUN mkdir -p /opt/toolchains/esp-idf/.vscode
COPY scripts/esp-idf/c_cpp_properties.json /c_cpp_properties.json

# Install QEMU (Espressif fork)
RUN python3 /opt/toolchains/esp-idf/tools/idf_tools.py install qemu-xtensa qemu-riscv32

#-------------------------------------------------------------------------------
# Mosquitto (optional)

# Store the flag for runtime use
ENV INSTALL_MOSQUITTO=${INSTALL_MOSQUITTO}

# Copy Mosquitto files to temp location (will be moved if INSTALL_MOSQUITTO=true)
COPY scripts/esp-idf/mosquitto.conf /tmp/mosquitto.conf
COPY scripts/esp-idf/generate_mosquitto_password.sh /tmp/generate_mosquitto_password.sh
COPY scripts/esp-idf/openssl.cnf /tmp/openssl.cnf
COPY scripts/esp-idf/ca.crt /tmp/ca.crt
COPY scripts/esp-idf/ca.key /tmp/ca.key

ARG HOSTNAME
RUN if [ "$INSTALL_MOSQUITTO" = "true" ]; then \
        apt-get -y update && \
        apt-get install --no-install-recommends -y \
            mosquitto \
            mosquitto-clients \
            openssl && \
        apt-get clean -y && \
        rm -rf /var/lib/apt/lists/* && \
        mv /tmp/mosquitto.conf /etc/mosquitto/mosquitto.conf && \
        mv /tmp/generate_mosquitto_password.sh /generate_mosquitto_password.sh && \
        chmod +x /generate_mosquitto_password.sh && \
        /generate_mosquitto_password.sh ${MOSQUITTO_USERNAME} ${MOSQUITTO_PASSWORD} && \
        mv /tmp/openssl.cnf /etc/ssl/openssl.cnf && \
        mkdir -p /etc/mosquitto/ca_certificates && \
        mv /tmp/ca.crt /etc/mosquitto/ca_certificates/ca.crt && \
        mv /tmp/ca.key /etc/mosquitto/ca_certificates/ca.key && \
        mkdir -p /run/mosquitto && \
        chown mosquitto:mosquitto /run/mosquitto && \
        chmod 755 /run/mosquitto && \
        chown -R mosquitto:mosquitto /etc/mosquitto/ca_certificates && \
        chmod 755 /etc/mosquitto/ca_certificates && \
        chmod 644 /etc/mosquitto/ca_certificates/ca.crt && \
        chmod 600 /etc/mosquitto/ca_certificates/ca.key && \
        echo "DNS.2 = ${HOSTNAME}.local" >> /etc/ssl/openssl.cnf && \
        mkdir -p /etc/mosquitto/certs && \
        openssl genrsa -out /etc/mosquitto/certs/server.key 4096 && \
        openssl req -new -key /etc/mosquitto/certs/server.key \
            -out /etc/mosquitto/certs/server.csr -config /etc/ssl/openssl.cnf && \
        openssl x509 -req -CAcreateserial -days 36500 \
            -in /etc/mosquitto/certs/server.csr \
            -CA /etc/mosquitto/ca_certificates/ca.crt \
            -CAkey /etc/mosquitto/ca_certificates/ca.key \
            -out /etc/mosquitto/certs/server.crt \
            -extensions req_ext -extfile /etc/ssl/openssl.cnf && \
        chown -R mosquitto:mosquitto /etc/mosquitto/certs && \
        chmod 755 /etc/mosquitto/certs && \
        chmod 644 /etc/mosquitto/certs/server.crt && \
        chmod 600 /etc/mosquitto/certs/server.key; \
    else \
        rm -f /tmp/mosquitto.conf /tmp/generate_mosquitto_password.sh \
              /tmp/openssl.cnf /tmp/ca.crt /tmp/ca.key; \
    fi

#-------------------------------------------------------------------------------
# Locale and Environment

# Initialize system locale (required by menuconfig)
RUN sed -i '/^#.*en_US.UTF-8/s/^#//' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Export environment variables system-wide
RUN echo "IDF_TOOLS_PATH=${IDF_TOOLS_PATH}" >> /etc/environment && \
    echo "IDF_VERSION=${IDF_VERSION}" >> /etc/environment

# Copy VS Code settings to ESP-IDF workspace
COPY scripts/esp-idf/settings.json /opt/toolchains/esp-idf/.vscode/settings.json

# Add alias and enable environment on terminal open
RUN echo "alias get_idf='. /opt/toolchains/esp-idf/export.sh'" >> /root/.bashrc && \
    echo ". /opt/toolchains/esp-idf/export.sh" >> /root/.bashrc

# Add compiler paths for IntelliSense
RUN /bin/bash -c "source /opt/toolchains/esp-idf/export.sh && \
    XTENSA_C_COMPILER_PATH=\$(whereis -b xtensa-esp-elf-gcc | cut -d ' ' -f2) && \
    XTENSA_CPP_COMPILER_PATH=\$(whereis -b xtensa-esp-elf-g++ | cut -d ' ' -f2) && \
    echo \"export XTENSA_C_COMPILER_PATH=\$XTENSA_C_COMPILER_PATH\" >> /root/.bashrc && \
    echo \"export XTENSA_CPP_COMPILER_PATH=\$XTENSA_CPP_COMPILER_PATH\" >> /root/.bashrc"

#-------------------------------------------------------------------------------
# Entrypoint

COPY scripts/esp-idf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
