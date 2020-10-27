#!/bin/sh
#
# This script starts the application container. If
# needed, it will seed the Docker repository with the firmware's built-in
# container image.

MANIFEST="/usr/share/container-images/images.manifest"

info() {
    echo "container-image: ${*}"
    logger -t "container-image" "${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

start_container() {
    local status
    local docker_name docker_image
    docker_image="${1}"
    docker_name="${2}"

    info "Starting container ${docker_image}..."
    status=$(docker inspect "${docker_image}" --format='{{.State.Status}}')

    case "${status}" in
    exited)
        # This case requires a different startup method
        docker start "${docker_name}"
        ;;
    running)
        die "${docker_image} already running..."
        ;;
    *)
        docker run ${DOCKER_OPTS} --name "${docker_name}" -d "${docker_image}"
        ;;
    esac
}

stop_container() {
    local docker_name
    docker_name="${1}"

    info "Stopping container ${docker_name}..."

    if ! docker stop "${docker_name}"; then
        die "Error stopping ${docker_name}"
    fi
}

remove_container() {
    local docker_name
    docker_name="${1}"

    info "Removing container ${docker_name}..."

    if ! docker rm "${docker_name}"; then
        die "Error removing ${docker_name}"
    fi
}

########################### MAIN SCRIPT ###########################

DOCKER_OPTS=""

case "$1" in
start)
    info "Starting containers from ${MANIFEST}"
    while read -r name version tag _; do
        start_container "${name}:${version}" "${tag}"|| die "Error starting the container ${name}"
        info "Success starting the container ${name}:${version}"
    done < "${MANIFEST}"
    ;;
stop)
    while read -r name version tag _; do
        stop_container "${tag}"
        remove_container "${tag}"
        info "Stopping the container ${tag}"
    done < "${MANIFEST}"
    ;;
*)
    die "Usage: $0 {start|stop}"
    ;;
esac
