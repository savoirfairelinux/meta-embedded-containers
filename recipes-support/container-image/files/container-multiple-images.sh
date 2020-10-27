#!/bin/sh
#
# This script starts the application container. If
# needed, it will seed the Docker repository with the firmware's built-in
# container image.

MANIFEST="/usr/share/container-images/images.manifest"
CONF_FILE="/usr/share/container-images/docker-compose.yml"

info() {
    echo "container-image: ${*}"
    logger -t "container-image" "${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

start_container() {
    local docker_name
    docker_name="${1}"

    if docker-compose -f "${CONF_FILE}" ps "${docker_name}" | grep -q "Up"; then
        info "${docker_name} is already up"
        return 0
    else
        info "Starting ${docker_name}"
    docker-compose -f "${CONF_FILE}" start "${docker_name}"
    fi
}

stop_container() {
    local docker_name
    docker_name="${1}"

    info "Stopping container ${docker_name}..."

    if ! docker-compose -f "${CONF_FILE}" stop "${docker_name}"; then
        die "Error stopping ${docker_name}"
    fi
}

# Start all the containers described in the docker-compose.yml file.
start() {
    info "Starting multiple containers ..."

    if docker-compose -f "${CONF_FILE}" start; then
        info "Starting the containers"
    else
        die "Error starting Airtime containers ..."
    fi
}

# Stop all the containers described in the docker-compose.yml file.
stop() {
    info "Stopping containers : ... "
    if docker-compose -f ${CONF_FILE} stop; then
        info "Containers stopped"
    else
        die "Error stopping Airtime containers ..."
    fi
}

# Start all the containers, network and volumes described in the
# docker-compose.yml file.
up() {
    info "Bringing up containers ..."
    if ! docker-compose -f "${CONF_FILE}" up -d --force-recreate; then
        die "Error bringing up Airtime containers ..."
    else
        info "Airtime containers started"
    fi
}

# Stop all the containers, network and volumes described in the
# docker-compose.yml file.
down() {
    info "Tearing down containers : ... "
    if ! docker-compose -f ${CONF_FILE} down -v --remove-orphans; then
        docker system prune --force
        die "Error tearing down Airtime containers, remove unused data ..."
    else
        info "Airtime containers teared down"
    fi
}

########################### MAIN SCRIPT ###########################

case "$1" in
start)
    up
#    info "Starting containers from ${MANIFEST}"
#    while read -r name version tag _; do
#        start_container "${name}:${version}" "${tag}"|| die "Error starting the container ${name}"
#        info "Success starting the container ${name}:${version}"
#    done < "${MANIFEST}"
    ;;
stop)
    down
#    while read -r name version tag _; do
#        stop_container "${tag}"
#        remove_container "${tag}"
#        info "Stopping the container ${tag}"
#    done < "${MANIFEST}"
    ;;
*)
    die "Usage: $0 {start|stop}"
    ;;
esac
