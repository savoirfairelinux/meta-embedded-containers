SUMMARY = "Embed multiple container archives in the system"
DESCRIPTION = "Pull the container images, save them in the rootfs \
    and start them with docker-compose at boot"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://images.manifest \
           file://container-multiple-images.service \
           file://container-multiple-images.sh \
           file://container-load.sh \
           file://docker-compose.yml \
          "

MANIFEST = "images.manifest"
STORE_DIR = "${WORKDIR}/container-store"

do_pull_image[nostamp] = "1"
do_tag_image[nostamp] = "1"
do_save_image[nostamp] = "1"

RDEPENDS_${PN} = "docker python3-docker-compose bash"
REQUIRED_DISTRO_FEATURES= "systemd"

inherit systemd
SYSTEMD_SERVICE_${PN} = "container-multiple-images.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

# Pull the container images from the manifest file.
do_pull_image() {

    [ -f "${WORKDIR}/${MANIFEST}" ] || bbfatal "${MANIFEST} does not exist"
    # Specify the PATH env variable allowing Bitbake:
    # - to look for podman binary as /usr/bin is not defined in the originally PATH env
    # variable.
    # - to call /usr/bin/newgidmap and /usr/bin/newuidmap binaries which
    # set uid and gid mapping of a user namespace.
    local name version
    while read -r name version _; do
        if ! PATH=/usr/bin:${PATH} podman pull "${name}:${version}"; then
            bbfatal "Error pulling ${name}:${version}"
        fi
    done < "${WORKDIR}/${MANIFEST}"
}

# Tag the container images with the tag specified in the manifest file.
do_tag_image() {
    [ -f "${WORKDIR}/${MANIFEST}" ] || bbfatal "${MANIFEST} does not exist"
    local name version tag
    while read -r name version tag _; do
        if ! PATH=/usr/bin:${PATH} podman tag "${name}:${version}" "${tag}:${version}"; then
            bbfatal "Error tagging ${name}:${version}"
        fi
    done < "${WORKDIR}/${MANIFEST}"
}

# Save the container images.
do_save_image() {
    local name version archive tag
    mkdir -p "${STORE_DIR}"
    while read -r name version tag _; do
        archive="${tag}-${version}.tar"
        if [ -f "${WORKDIR}/${archive}" ]; then
            bbnote "Removing the archive ${STORE_DIR}/${archive}"
            rm "${WORKDIR}/${archive}"
        fi

        if ! PATH=/usr/bin:${PATH} podman save --storage-driver overlay "${tag}:${version}" \
            -o "${WORKDIR}/${archive}"; then
            bbfatal "Error saving ${tag} container"
        fi
    done < "${WORKDIR}/${MANIFEST}"
}

# Install the manifest inside the root filesystem.
do_install() {
    local name version archive tag
    install -d "${D}${datadir}/container-images"
    install -m 0400 "${WORKDIR}/${MANIFEST}" "${D}${datadir}/container-images/"
    install -m 0400 "${WORKDIR}/docker-compose.yml" "${D}${datadir}/container-images/"
    while read -r name version tag _; do
        archive="${tag}-${version}.tar"
        [ -f "${WORKDIR}/${archive}" ] || bbfatal "${archive} does not exist"

        install -m 0400 "${WORKDIR}/${archive}" "${D}${datadir}/container-images/"
    done < "${WORKDIR}/${MANIFEST}"

    install -d "${D}${systemd_unitdir}/system"
    install -m 0644 "${WORKDIR}/container-multiple-images.service" "${D}${systemd_unitdir}/system"
    install -d "${D}${bindir}"
    install -m 0755 "${WORKDIR}/container-multiple-images.sh" "${D}${bindir}/container-multiple-images"
    install -m 0755 "${WORKDIR}/container-load.sh" "${D}${bindir}/container-load"
}

# The ordre should be:
# 1. do_fetch
# 2. do_pull_image
# 3. do_tag_image
# 4. do_save_image
# 5. do_install
addtask pull_image before do_tag_image after do_fetch
addtask tag_image before do_save_image after do_pull_image
addtask save_image before do_install after do_tag_image

FILES_${PN} = "${datadir}/container-images \
               ${system_unitdir}/system/container-multiple-images.service \
               ${bindir}/container-multiple-images \
               ${bindir}/container-load \
              "
