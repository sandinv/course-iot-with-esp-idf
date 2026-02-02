#!/bin/bash

# Source .bashrc to ensure the path is set
source $HOME/.bashrc

# Set global environment variables
source /etc/environment
export IDF_COMPILER_PATH
export XTENSA_C_COMPILER_PATH=$(whereis -b xtensa-esp-elf-gcc | cut -d ' ' -f2)
export XTENSA_CPP_COMPILER_PATH=$(whereis -b xtensa-esp-elf-g++ | cut -d ' ' -f2)

# Copy the C/C++ extension configuration
mkdir -p /workspace/project/apps/.vscode
cp /c_cpp_properties.json /workspace/project/apps/.vscode/c_cpp_properties.json

# Start Mosquitto if installed
if [ "$INSTALL_MOSQUITTO" = "true" ] && command -v mosquitto &> /dev/null; then
    echo "Starting Mosquitto MQTT broker..."
    /usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf -d
fi

# Keep the container running
exec sleep infinity
