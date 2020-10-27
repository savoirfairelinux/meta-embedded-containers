require recipes-core/images/core-image-base.bb

DESCRIPTION = "Core image with embedded container images"

IMAGE_FSTYPES += "squashfs"

WKS_FILE = "embedded-container.wks"

IMAGE_FEATURES_append = "\
    debug-tweaks \
    post-install-logging \
    read-only-rootfs \
    ssh-server-dropbear \
    "

IMAGE_INSTALL_append = " \
    container-image \
    docker \
    "

update_fstab_image() {
    install -d "${IMAGE_ROOTFS}/${datadir}/docker-store"

    cat >> "${IMAGE_ROOTFS}/${sysconfdir}/fstab" <<EOF

tmpfs       ${datadir}/docker-store  tmpfs defaults 0 0

overlay     /var/lib/docker overlay noauto,rw,relatime,lowerdir=/var/lib/docker,upperdir=${datadir}/docker-store/docker,workdir=${datadir}/docker-store/.docker,x-systemd.requires-mounts-for=${datadir}/docker-store

/tmp/docker-data /etc/docker none noauto,bind 0 2

EOF
}

update_fstab_archive() {
    install -d "${IMAGE_ROOTFS}/${datadir}/docker-store"

    cat >> "${IMAGE_ROOTFS}${sysconfdir}/fstab" <<EOF

tmpfs       ${datadir}/docker-store  tmpfs defaults 0 0

${datadir}/docker-store /var/lib/docker none noauto,bind 0 2

/tmp/docker-data /etc/docker none noauto,bind 0 2

EOF
}

# Add the extract_docker_store command only if container-image is
# present in the IMAGE_INSTALL Bitbake variable.
ROOTFS_POSTPROCESS_COMMAND += "${@bb.utils.contains("IMAGE_INSTALL","container-image", "update_fstab_image;", "", d)}"

ROOTFS_POSTPROCESS_COMMAND += "${@bb.utils.contains("IMAGE_INSTALL","container-archive","update_fstab_archive;", "", d)}"
