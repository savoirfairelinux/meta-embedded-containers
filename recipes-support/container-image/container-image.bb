SUMMARY = "Embed Docker store in the system"
DESCRIPTION = "Pull the container image(s) and install the Docker store"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

DOCKER_STORE = "${WORKDIR}/docker-store"

MANIFEST = "images.manifest"

inherit systemd
SYSTEMD_SERVICE_${PN} = "container-image.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

RDEPENDS_${PN} += "docker bash mount-noauto"

SRC_URI = "file://container-image.service \
           file://container-image.sh \
           file://images.manifest \
          "

do_pull_image[nostamp] = "1"
do_package_qa[noexec] = "1"
INSANE_SKIP_${PN}_append = "already-stripped"
EXCLUDE_FROM_SHLIBS = "1"

do_pull_image() {
    [ -f "${WORKDIR}/${MANIFEST}" ] || bbfatal "${MANIFEST} does not exist"

    [ -n "$(pidof dockerd)" ] && sudo kill "$(pidof dockerd)" && sleep 5

    [ -d "${DOCKER_STORE}" ] && sudo rm -rf "${DOCKER_STORE}"/*

    # Start the dockerd daemon with the driver vfs in order to store the
    # container layers into vfs layers. The default storage is overlay
    # but it will not work on the target system as /var/lib/docker is
    # mounted as an overlay and overlay storage driver is not compatible
    # with overlayfs.
    sudo /usr/bin/dockerd --storage-driver vfs --data-root "${DOCKER_STORE}" &

    # Wait a little before pulling to let the daemon be ready.
    sleep 5

    if ! sudo docker info; then
        bbfatal "Error launching docker daemon"
    fi

    local name version tag
    while read -r name version tag _; do
        if ! sudo docker pull "${name}:${version}"; then
            bbfatal "Error pulling ${name}"
        fi
    done < "${WORKDIR}/${MANIFEST}"

    sudo chown -R "${USER}" "${DOCKER_STORE}"

    # Clean temporary folders in the docker store.
    rm -rf "${DOCKER_STORE}/runtimes"
    rm -rf "${DOCKER_STORE}/tmp"

    # Kill dockerd daemon after use.
    sudo kill "$(pidof dockerd)"
}

do_install() {
    install -d "${D}${systemd_unitdir}/system"
    install -m 0644 "${WORKDIR}/container-image.service" "${D}${systemd_unitdir}/system/"

    install -d "${D}${bindir}"
    install -m 0755 "${WORKDIR}/container-image.sh" "${D}${bindir}/container-image"

    install -d "${D}${datadir}/container-images"
    install -m 0400 "${WORKDIR}/${MANIFEST}" "${D}${datadir}/container-images/"

    install -d "${D}${localstatedir}/lib/docker"
    cp -R "${DOCKER_STORE}"/* "${D}${localstatedir}/lib/docker/"
}

FILES_${PN} = "\
    ${system_unitdir}/system/container-image.service \
    ${bindir}/container-image \
    ${datadir}/container-images/${MANIFEST} \
    ${datadir}/docker-store \
    ${datadir}/docker-data \
    ${localstatedir}/lib/docker \
    "

addtask pull_image before do_install after do_fetch

REQUIRED_DISTRO_FEATURES= "systemd"
