#!/bin/sh
#
# This script starts the application container for the TSI application. If
# needed, it will seed the Docker repository with the firmware's built-in
# container image.

TSI_ARCHIVE="/usr/share/TSI/tsi-docker-image.tar"
TSI_REPO="harbor.thinksurgical.com/sfl/xenial-tmini"
TSI_IMAGENAME="tsi-image"

info() {
    echo "tsi-image: ${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

# Check if the image from a repository is loaded
is_image_loaded() {
    local output=$(docker images --format='{{.Repository}}' ${TSI_REPO})
    test -n "${output}"
}

# Load a "docker save" archive into the docker store
load_image() {
    info "Loading the ${TSI_ARCHIVE} into the docker store..."

    if ! docker load -i "${TSI_ARCHIVE}"; then
        die "Error loading the ${TSI_ARCHIVE} into the docker store"
    fi
}

start_container() {
    local status

    info "Starting container ${TSI_IMAGENAME}..."
    status=$(docker inspect "${TSI_IMAGENAME}" --format='{{.State.Status}}')

    case "${status}" in
    exited)
        # This case requires a different startup method
        docker start "${TSI_IMAGENAME}"
        ;;
    running)
        die "${TSI_IMAGENAME} already running..."
        ;;
    *)
        docker run ${DOCKER_OPTS} --name "${TSI_IMAGENAME}" -d "${TSI_REPO}"
        ;;
    esac
}

stop_container() {
    info "Stopping container ${TSI_IMAGENAME}..."

    if ! docker stop "${TSI_IMAGENAME}"; then
        die "Error stopping ${TSI_IMAGENAME}"
    fi
}

########################### MAIN SCRIPT ###########################

[ -f "${TSI_ARCHIVE}" ] || die "${TSI_ARCHIVE} not found"

# Set the DISPLAY to :0 if not defined
[ -n "${DISPLAY}" ] || DISPLAY=":0"

[ -d /run/media ] || mkdir -p /run/media

DOCKER_OPTS="-e DISPLAY=${DISPLAY}
    -v /tmp/.X11-unix/:/tmp/.X11-unix
    -v /dev/dri/:/dev/dri
    -v /dev/snd:/dev/snd
    -v /dev/vldrive:/dev/vldrive
    -v /dev/vldrivep:/dev/vldrivep
    -v /dev/vldriveax:/dev/vldriveax
    -v /dev/cgos:/dev/cgos
    -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket
    -e PULSE_SERVER=unix:/run/pulse/native
    -v /run/pulse/native:/run/pulse/native
    -v /etc/pulse/client.conf:/etc/pulse/client.conf
    --mount type=bind,source=/run/media,target=/run/media,bind-propagation=rslave
    --group-add audio"

case "$1" in
start)
    is_image_loaded || load_image
    start_container || die "Error starting the container ${TSI_IMAGENAME}"
    echo "Success starting the container..."
    ;;
stop)
    stop_container
    ;;
*)
    die "Usage: $0 {start|stop}"
    ;;
esac
