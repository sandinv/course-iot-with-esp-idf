# Settings
ARG DEBIAN_VERSION=stable-20241223-slim
ARG IDF_VERSION=5.4.1

# Target chips to install (space-separated: esp32 esp32s2 esp32s3 esp32c3 esp32c6 esp32h2)
ARG IDF_TARGETS="esp32"

# Optional features
ARG INSTALL_MOSQUITTO=false
ARG MOSQUITTO_USERNAME="iot"
ARG MOSQUITTO_PASSWORD="mosquitto"

#-------------------------------------------------------------------------------
# Base Image and Dependencies

FROM debian:${DEBIAN_VERSION}

ARG TARGETARCH
ARG IDF_VERSION
ARG IDF_TARGETS
ARG INSTALL_MOSQUITTO
ARG MOSQUITTO_USERNAME
ARG MOSQUITTO_PASSWORD

SHELL ["/bin/bash", "-c"]

# Check architecture
RUN if [ "$TARGETARCH" != "amd64" ] && [ "$TARGETARCH" != "arm64" ]; then \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages and clean up in one layer
RUN apt-get -y update && \
    apt-get install --no-install-recommends -y \
        wget curl git ca-certificates \
        locales \
        python3 python3-pip python3-venv \
        xz-utils \
        flex bison gperf \
        cmake ninja-build ccache \
        build-essential \
        libffi-dev libssl-dev libusb-1.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set up directories
RUN mkdir -p /workspace/apps /opt/toolchains

#-------------------------------------------------------------------------------
# ESP-IDF

ENV IDF_VERSION=${IDF_VERSION}
ENV IDF_TOOLS_PATH=/opt/toolchains/espressif

# Download and install ESP-IDF
RUN cd /opt/toolchains && \
    git clone --recursive --branch v${IDF_VERSION} --depth 1 \
        --shallow-submodules https://github.com/espressif/esp-idf.git && \
    cd esp-idf && \
    ./install.sh ${IDF_TARGETS}

# Get compiler path for IntelliSense
RUN . /opt/toolchains/esp-idf/export.sh && \
    echo "IDF_COMPILER_PATH=$(which xtensa-esp32-elf-gcc 2>/dev/null || which riscv32-esp-elf-gcc 2>/dev/null || echo '')" >> /etc/environment

# Copy C/C++ IntelliSense configuration
COPY scripts/esp-idf/c_cpp_properties.json /c_cpp_properties.json

#-------------------------------------------------------------------------------
# Mosquitto (optional)

ENV INSTALL_MOSQUITTO=${INSTALL_MOSQUITTO}

COPY scripts/esp-idf/mosquitto.conf /tmp/mosquitto.conf
COPY scripts/esp-idf/generate_mosquitto_password.sh /tmp/generate_mosquitto_password.sh
COPY scripts/esp-idf/openssl.cnf /tmp/openssl.cnf
COPY scripts/esp-idf/ca.crt /tmp/ca.crt
COPY scripts/esp-idf/ca.key /tmp/ca.key

ARG HOSTNAME
RUN if [ "$INSTALL_MOSQUITTO" = "true" ]; then \
        apt-get -y update && \
        apt-get install --no-install-recommends -y mosquitto mosquitto-clients openssl && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && \
        mv /tmp/mosquitto.conf /etc/mosquitto/mosquitto.conf && \
        mv /tmp/generate_mosquitto_password.sh /generate_mosquitto_password.sh && \
        chmod +x /generate_mosquitto_password.sh && \
        /generate_mosquitto_password.sh ${MOSQUITTO_USERNAME} ${MOSQUITTO_PASSWORD} && \
        mv /tmp/openssl.cnf /etc/ssl/openssl.cnf && \
        mkdir -p /etc/mosquitto/ca_certificates /etc/mosquitto/certs /run/mosquitto && \
        mv /tmp/ca.crt /etc/mosquitto/ca_certificates/ca.crt && \
        mv /tmp/ca.key /etc/mosquitto/ca_certificates/ca.key && \
        chown -R mosquitto:mosquitto /etc/mosquitto/ca_certificates /run/mosquitto && \
        chmod 755 /etc/mosquitto/ca_certificates /run/mosquitto && \
        chmod 644 /etc/mosquitto/ca_certificates/ca.crt && \
        chmod 600 /etc/mosquitto/ca_certificates/ca.key && \
        [ -n "$HOSTNAME" ] && echo "DNS.2 = ${HOSTNAME}.local" >> /etc/ssl/openssl.cnf || true && \
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

RUN sed -i '/^#.*en_US.UTF-8/s/^#//' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN echo "IDF_TOOLS_PATH=${IDF_TOOLS_PATH}" >> /etc/environment && \
    echo "IDF_VERSION=${IDF_VERSION}" >> /etc/environment

COPY scripts/esp-idf/settings.json /opt/toolchains/esp-idf/.vscode/settings.json

RUN echo "alias get_idf='. /opt/toolchains/esp-idf/export.sh'" >> /root/.bashrc && \
    echo ". /opt/toolchains/esp-idf/export.sh" >> /root/.bashrc

RUN /bin/bash -c "source /opt/toolchains/esp-idf/export.sh && \
    XTENSA_C_COMPILER_PATH=\$(which xtensa-esp32-elf-gcc 2>/dev/null || echo '') && \
    XTENSA_CPP_COMPILER_PATH=\$(which xtensa-esp32-elf-g++ 2>/dev/null || echo '') && \
    echo \"export XTENSA_C_COMPILER_PATH=\$XTENSA_C_COMPILER_PATH\" >> /root/.bashrc && \
    echo \"export XTENSA_CPP_COMPILER_PATH=\$XTENSA_CPP_COMPILER_PATH\" >> /root/.bashrc"

#-------------------------------------------------------------------------------
# Entrypoint

# Copy workspace file (repo will be mounted at /workspace/project)
COPY .devcontainer/esp-idf.code-workspace /workspace/esp-idf.code-workspace

WORKDIR /workspace

COPY scripts/esp-idf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
