# ESP-IDF Development Environment

A devcontainer-based development environment for ESP32 firmware development using ESP-IDF.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [VS Codium](https://vscodium.com/) or VS Code with [Dev Containers extension](https://open-vsx.org/extension/ms-vscode-remote/remote-containers)
- (Windows) [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install)
- (Windows) [Virtual COM port drivers from SiLabs](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers?tab=downloads)

## Getting Started

1. Clone this repository
2. Open the folder in VS Codium/VS Code
3. When prompted, click "Reopen in Container" (or use Command Palette: **Dev Containers: Reopen in Container**)
4. Wait for the container to build (first time takes a while due to ESP-IDF installation)

Your apps go in the `apps/` folder, which is bind-mounted into the container at `/workspace/apps`.

## Configuration

Edit `.devcontainer/devcontainer.json` to customize the environment:

### ESP-IDF Version and Targets

```json
"args": {
    "IDF_VERSION": "5.4.1",
    "IDF_TARGETS": "esp32"
}
```

`IDF_TARGETS` controls which chip toolchains are installed. Options: `esp32`, `esp32s2`, `esp32s3`, `esp32c3`, `esp32c6`, `esp32h2`.

For multiple targets (increases image size):

```json
"args": {
    "IDF_VERSION": "5.4.1",
    "IDF_TARGETS": "esp32 esp32s3 esp32c3"
}
```

### Enable Mosquitto MQTT Broker

To enable the Mosquitto MQTT broker (disabled by default):

```json
"args": {
    "INSTALL_MOSQUITTO": "true"
}
```

When enabled, Mosquitto runs with TLS support on ports:
- 1883 (MQTT)
- 8883 (MQTTS)

Default credentials: `iot` / `mosquitto`

Add port mappings to `runArgs` if needed:

```json
"runArgs": [
    "--network=bridge",
    "-p", "1883:1883",
    "-p", "8883:8883"
]
```

## Project Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json    # Dev container configuration
│   └── Dockerfile           # Container image definition
├── apps/                    # Your ESP-IDF applications (bind-mounted)
└── scripts/
    └── esp-idf/             # Support scripts and configs
```

Inside the container:
- `/workspace/apps` - Your applications (mounted from host)
- `/opt/toolchains/esp-idf` - ESP-IDF framework
- `/opt/toolchains/espressif` - ESP-IDF tools

## Using Taskfile

This project uses [Task](https://taskfile.dev/) to manage build and flash operations. Install it on macOS:

```sh
brew install go-task
```

### Host Dependencies

Install Python dependencies for flashing:

```sh
python -m venv venv
source venv/bin/activate
pip install pyserial esptool
```

### Workflow

1. Start the devcontainer in Codium/VS Code
2. Get the container name: `task ps`
3. Build and flash your app

### Build Commands (run in container via docker exec)

```sh
# Build an application
task build APP=my_app CONTAINER=container_name

# Open menuconfig
task menuconfig APP=my_app CONTAINER=container_name

# Clean build
task clean APP=my_app CONTAINER=container_name

# Show size info
task size APP=my_app CONTAINER=container_name
```

### Flash Commands (run natively on macOS)

```sh
# Flash to device (default port: /dev/cu.usbserial-0001)
task flash APP=my_app

# Flash with custom port
task flash APP=my_app PORT=/dev/cu.usbmodem1234

# Open serial monitor
task monitor APP=my_app

# Erase flash
task erase-flash
```

### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| APP | (required) | Application name in `apps/` |
| CONTAINER | (required for build) | Docker container name |
| PORT | /dev/tty.usbserial-0001 | Serial port |
| BAUD | 460800 | Flash baud rate |
| TARGET | esp32 | Target chip |

### Utility Commands

```sh
task list   # List available apps
task ps     # Show running containers
```

## Regenerating CA Certificates

If you need to regenerate the Certificate Authority key and certificate for Mosquitto TLS:

```sh
docker build -t ca-gen -f Dockerfile.ca-gen .
docker run --rm -v "$(pwd)/scripts/esp-idf:/output" ca-gen
docker image rm ca-gen
```

Then rebuild the devcontainer.

## License

Licensed under the [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) license.
