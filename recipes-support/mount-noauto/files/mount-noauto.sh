#!/bin/sh
#
# Script to mount all the noauto entries of the /etc/fstab file.
#

FSTAB_FILE="/etc/fstab"

die() {
    echo "Fatal: ${*}"
    exit 1
}

# Mount noauto filesystem described in the partition-layout file.
mount_noauto() {
    local device mntpt fstype opts ret overlaydirs
    while read -r device mntpt fstype opts _; do

        echo "${device}" | grep -q "^#" && continue

        echo "${opts}" | grep -q "noauto" || continue

        if [ "${fstype}" = "overlay" ]; then
            device="${mntpt}"

            overlaydirs=$(echo "${opts}" |
                      tr "," "\n" |
                      grep "workdir\|upperdir" |
                      sed -r 's/.*dir=//' )

            for d in ${overlaydirs}; do
                mkdir -p "${d}"
            done
        elif [ ! -d "${device}" ] || [ ! -d "${mntpt}" ] ; then
            mkdir -p "${device}"
            mkdir -p "${mntpt}"
        fi

        echo "${opts}" | grep -q "bind" && device="${mntpt}"

        echo "Mounting noauto ${device}..."
        mount "${device}"
        ret=${?}

        case "${ret}" in
        0)
            echo "${device} mounted successfully on ${mntpt}"
            ;;
        64)
            echo "${device} mounted with errors on ${mntpt}, code ${ret}"
            ;;
        *)
            echo "Mounting ${device} on ${mntpt} FAILURE! code ${ret}"
            return ${ret}
            ;;
        esac

    done < "${FSTAB_FILE}"
}

########################### MAIN SCRIPT ###########################

[ -f "${FSTAB_FILE}" ] || die "${FSTAB_FILE} does not exist"

case "${1}" in
start)
    mount_noauto || die "Error loading noauto entries..."
    ;;
stop)
    ;;
*)
    die "Usage: $0 {start}"
    ;;
esac
