#!/bin/bash
#
# This script loads all the container images contained in the manifest
# file.
#

IMAGE_DIR="/usr/share/container-images"
MANIFEST="${IMAGE_DIR}/images.manifest"

info() {
    echo "container-load: ${*}"
    logger -t "container-load" "${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

# Check if the image from a repository is loaded. The archive name is
# named like '/usr/share/images/${name}-${version}.tar' and
# the docker images are tagged as 'localhost/${name}' in the
# docker local registry.
# $1: the image name
is_image_loaded() {
    local image image_name image_version output
    image="${1}"
    image_name="localhost/$(basename "${image}".tar | cut -d- -f1)"
    image_version="$(basename "${image}".tar | cut -d- -f2)"
    output=$(docker images --format='{{.Repository}} {{.Tag}}' "${image_name}")
    test "${output}" = "${image_name} ${image_version}"
}

# Load a "docker save" archive into the docker store.
load_image() {
    local image="${1}"
    info "Loading the ${image} into the docker store..."

    if ! docker load -i "${image}"; then
        die "Error loading the ${image} into the docker store"
    fi
}

# Tag the images described in the manifest to "latest" tag.
tag_images() {
    [ -f "${MANIFEST}" ] ||
        die "${MANIFEST} is not installed on the system"

    local name version image
    while read -r name version image _; do
        docker tag "localhost/${image}:${version}" "localhost/${image}:latest" ||
            die "Error tagging localhost/${image}:${version}"

        docker tag "localhost/${image}:${version}" "${name}:${version}" ||
            die "Error tagging ${name}:${version}"
    done < ${MANIFEST}
}

########################### MAIN SCRIPT ###########################

case "${1}" in
start)
    for img in "${IMAGE_DIR}"/*.tar; do
        is_image_loaded "${img}" || load_image "${img}"
        info "Succes loading ${img}..."
    done
    info "Success loading all the images..."
    tag_images
    info "Success tagging all the images to the latest tag..."
    ;;
*)
    die "Usage: ${0} start"
    ;;
esac
