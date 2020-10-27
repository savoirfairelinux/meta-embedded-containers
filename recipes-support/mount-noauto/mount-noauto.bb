SUMMARY = "Mount noauto filesystems"
DESCRIPTION = "Mount the noauto filesystems systemd service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

inherit systemd
SYSTEMD_SERVICE_${PN} = "mount-noauto.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

REQUIRED_DISTRO_FEATURES= "systemd"

SRC_URI = "file://mount-noauto.service \
           file://mount-noauto.sh \
          "

do_install() {
    install -d "${D}${systemd_unitdir}/system"
    install -m 0644 "${WORKDIR}/mount-noauto.service" "${D}${systemd_unitdir}/system"
    install -d "${D}${bindir}"
    install -m 0755 "${WORKDIR}/mount-noauto.sh" "${D}${bindir}/mount-noauto"
}

FILES_${PN} = "${bindir}/mount-noauto \
               ${system_unitdir} \
               ${system_unitdir}/system \
               ${system_unitdir}/mount-noauto.service \
              "
