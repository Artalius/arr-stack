#!/bin/bash
#set -x #full StdOut for debugging
# Load from the .env file
if [ -f .env ]; then
    ARR_STACK_PATH=$(grep '^ARR_STACK_PATH=' .env | cut -d '=' -f2- | tr -d '"')
    DISCORD_TOKEN=$(grep '^DISCORD_TOKEN=' .env | cut -d '=' -f2- | tr -d '"')
    BAZARR_API=$(grep '^BAZARR_API=' .env | cut -d '=' -f2- | tr -d '"')
    LIDARR_API=$(grep '^LIDARR_API=' .env | cut -d '=' -f2- | tr -d '"')
    OVERSEERR_API=$(grep '^OVERSEERR_API=' .env | cut -d '=' -f2- | tr -d '"')
    RADARR_API=$(grep '^RADARR_API=' .env | cut -d '=' -f2- | tr -d '"')
    READARR_API=$(grep '^READARR_API=' .env | cut -d '=' -f2- | tr -d '"')
    SONARR_API=$(grep '^SONARR_API=' .env | cut -d '=' -f2- | tr -d '"')
    WHISPARR_API=$(grep '^WHISPARR_API=' .env | cut -d '=' -f2- | tr -d '"')
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

# Use ARR_STACK_PATH in the script
DIRECTORIES=(
  "$ARR_STACK_PATH"
  "$ARR_STACK_PATH/data"
  "$ARR_STACK_PATH/data/bazarr"
  "$ARR_STACK_PATH/data/doplarr"
  "$ARR_STACK_PATH/data/lidarr"
  "$ARR_STACK_PATH/data/overseerr"
  "$ARR_STACK_PATH/data/prowlarr"
  "$ARR_STACK_PATH/data/radarr"
  "$ARR_STACK_PATH/data/readarr"
  "$ARR_STACK_PATH/data/sonarr"
  "$ARR_STACK_PATH/data/unpackerr"
  "$ARR_STACK_PATH/data/whisparr"
  "$ARR_STACK_PATH/data/wizarr"
)

# Function to install Docker and Docker Compose via TDNF
install_dependencies() {
  echo "🔧 Installing Docker and Docker Compose via TDNF..."

  # Install Docker
  if ! command -v docker &>/dev/null; then
    echo "⚙️ Docker not found, installing..."
    tdnf install -y docker
  else
    echo "✅ Docker is already installed."
  fi

  # Install Docker Compose
  if ! command -v docker-compose &>/dev/null; then
    echo "⚙️ Docker Compose not found, installing..."
    tdnf install -y docker-compose
  else
    echo "✅ Docker Compose is already installed."
  fi
}

# Function to create directories if they don't exist
create_directories() {
  echo "🗂️ Checking and creating missing directories..."
  echo "📜 Base Directory path is \"$ARR_STACK_PATH\""
  for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
      echo "🚧 Directory is missing, Creating: \"$dir\""
      mkdir -p "$dir"
    else
      echo "✅ Directory exists: \"$dir\""
    fi
  done
}

# Function to check file permissions
check_permissions() {
  echo "🔐 Checking file permissions for required directories..."
    perms=$(stat -c "%a" "$dir")
    owner=$(stat -c "%U" "$dir")
    group=$(stat -c "%G" "$dir")
    echo "📜 Checking Permissions: $perms, Owner: $owner, and Group: $group"
  for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
      if [ "$perms" -lt 755 ]; then
        echo "⚠️ Warning: Directory does not have the recommended permissions (755), Correcting: \"$dir\""
        sudo chmod 755 "$dir"
      else
        echo "✅ Permissions are valid for \"$dir\""
      fi
    fi
  done
}

# Function to validate API keys
validate_api_keys() {
    local missing_keys=0  # Counter for unset or placeholder keys

    declare -A api_keys=(
        ["DISCORD_TOKEN"]="$DISCORD_TOKEN"
        ["BAZARR_API"]="$BAZARR_API"
        ["LIDARR_API"]="$LIDARR_API"
        ["OVERSEERR_API"]="$OVERSEERR_API"
        ["RADARR_API"]="$RADARR_API"
        ["READARR_API"]="$READARR_API"
        ["SONARR_API"]="$SONARR_API"
        ["WHISPARR_API"]="$WHISPARR_API"
    )

    echo "🔑 Validating API keys..."

    for key in "${!api_keys[@]}"; do
        if [[ -z "${api_keys[$key]}" || "${api_keys[$key]}" == "api_key_here" ]]; then
            echo "❌ WARNING: \"$key\" is missing or still contains 'api_key_here'"
            missing_keys=$((missing_keys + 1))
        else
            echo "✅ \"$key\" is set correctly."
        fi
    done

    if [ "$missing_keys" -eq 0 ]; then
        echo "🎉 All API keys are set correctly!"
    else
        echo "⚠️ \"$missing_keys\" API keys still need to be updated!"
        exit 1
    fi
}

# Check Docker installation
echo "🛠️ Checking Docker installation..."
if ! command -v docker &>/dev/null; then
    echo "⚙️ Docker is not installed. Installing via TDNF."
    install_dependencies
else
    echo "✅ Docker is installed: $(docker --version)"
fi

# Check Docker Compose installation
echo "🛠️ Checking Docker Compose installation..."
if ! command -v docker-compose &>/dev/null; then
    echo "⚙️ Docker Compose is not installed. Installing via TDNF."
    install_dependencies
else
    echo "✅ Docker Compose is installed: $(docker-compose --version)"
fi
echo ""

# Create missing directories if needed
create_directories
echo ""

# Check file permissions for the required directories
check_permissions
echo ""

# Final check for docker.sock file
echo "🛑 Checking if Docker socket file exists..."
if [ ! -e "/var/run/docker.sock" ]; then
    echo "❌ Docker socket file /var/run/docker.sock is missing. Please ensure Docker is running."
    exit 1
else
    echo "✅ Docker socket file /var/run/docker.sock exists."
fi
echo ""

echo "🔧 OS and dependency validation complete."
echo ""

if command -v docker-compose &>/dev/null; then
    echo "🚀 Now stage Docker via Pull, DryRun, and No-Start."
    
    # Set the path to your Docker Compose YAML file
    COMPOSE_FILE="./docker-compose.yaml"

    # Check if the docker-compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ Error: docker-compose file \"$COMPOSE_FILE\" not found."
        exit 1
    fi

    # Pull the latest images using docker-compose
    echo "🔄 Pulling the latest images..."
    docker-compose -f "$COMPOSE_FILE" pull
    if [ $? -eq 0 ]; then
        echo "✅ Docker images pulled successfully."

        # Run docker-compose in dry-run mode (only validate the configuration)
        echo "⚙️ Running dry-run to validate configuration..."
        docker-compose -f "$COMPOSE_FILE" up --dry-run
        if [ $? -eq 0 ]; then
            echo "✅ Dry-run completed successfully."

            # If dry-run is successful, run docker-compose up with --no-start
            echo "🚀 Running docker-compose up with --no-start..."
            docker-compose -f "$COMPOSE_FILE" up --no-start
            if [ $? -eq 0 ]; then
                echo "✅ docker-compose up --no-start executed successfully."
            else
                echo "❌ Error: docker-compose up --no-start failed."
                exit 1
            fi
        else
            echo "❌ Error: docker-compose up --dry-run failed."
            exit 1
        fi
    else
        echo "❌ Error: docker-compose pull failed."
        exit 1
    fi
else
    echo "❌ Error: Setup failed to find or install docker-compose."
    exit 1
fi

echo "🔑 Now checking API keys"
validate_api_keys
echo ""

echo "🎉 If no errors, then the ARR Stack may be run!"
echo ""
