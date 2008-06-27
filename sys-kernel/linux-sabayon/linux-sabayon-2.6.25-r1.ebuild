# Copyright 2007 Sabayon Linux
# Distributed under the terms of the GNU General Public License v2

ETYPE="sources"
K_WANT_GENPATCHES=""
K_GENPATCHES_VER=""
inherit kernel-2
detect_version
detect_arch

MY_PV="${PV/-r1/}"
MY_P="${P/-r1/}"
UNIPATCH_STRICTORDER="yes"
KEYWORDS="~amd64 ~x86"
HOMEPAGE="http://www.sabayonlinux.org"
DEPEND="
	!only_sources? ( ~sys-kernel/genkernel-3.4.9 )
	splash? ( x11-themes/sabayonlinux-artwork )
	!=sys-kernel/sabayon-sources-${PVR/-r0/}
	"
RDEPEND="grub? ( sys-boot/grub )"
IUSE="splash dmraid grub no_sources only_sources"

DESCRIPTION="Official Sabayon Linux kernel images and sources"
KV_FULL=${KV_FULL/linux/sabayon}
K_NOSETEXTRAVERSION="1"
EXTRAVERSION=${EXTRAVERSION/linux/sabayon}
SLOT="${PVR/-r1/}"
S="${WORKDIR}/linux-${KV_FULL}"
UNIONFS_PATCH="unionfs-2.3.3_for_${MY_PV}.diff.gz"

## INIT: Exported data
SL_PATCHES_URI="http://download.filesystems.org/unionfs/unionfs-2.x/${UNIONFS_PATCH}"

SUSPEND2_VERSION="3.0-rc7"
SUSPEND2_TARGET="2.6.25"
SUSPEND2_SRC="tuxonice-${SUSPEND2_VERSION}-for-${SUSPEND2_TARGET}"
SUSPEND2_URI="http://www.tuxonice.net/downloads/all/${SUSPEND2_SRC}.patch.bz2"
UNIPATCH_LIST="
		${FILESDIR}/${MY_PV}/${MY_P}-from-ext4dev-to-ext4.patch
		${DISTDIR}/${SUSPEND2_SRC}.patch.bz2
		${FILESDIR}/${MY_PV}/${MY_P}-atl2.patch
		${FILESDIR}/${MY_PV}/patch-2.6.25.9.bz2
		${FILESDIR}/${MY_PV}/${MY_P}-at76.patch
		${DISTDIR}/${UNIONFS_PATCH}
		${FILESDIR}/${MY_PV}/${MY_P}-aufs.patch
"


# gentoo patches
for patch in `/bin/ls ${FILESDIR}/${MY_PV}/genpatches`; do
	UNIPATCH_LIST="${UNIPATCH_LIST} ${FILESDIR}/${MY_PV}/genpatches/${patch}"
done
# redhat patches
for patch in `/bin/ls ${FILESDIR}/${MY_PV}/redhat`; do
	UNIPATCH_LIST="${UNIPATCH_LIST} ${FILESDIR}/${MY_PV}/redhat/${patch}"
done

if use amd64; then
	UNIPATCH_LIST="${UNIPATCH_LIST} ${FILESDIR}/${MY_PV}/${MY_P}-enable-tlb-on-x86_64.patch"
fi

SRC_URI="${KERNEL_URI} ${SL_PATCHES_URI} ${SUSPEND2_URI}"

## END: Exported data

src_unpack() {
	kernel-2_src_unpack
	cd "${S}"
	# manually set extraversion
	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile

}

src_compile() {

	if ! use only_sources; then

		# disable sandbox
		export SANDBOX_ON=0

		# creating workdirs
		mkdir -p ${WORKDIR}/boot/grub
		mkdir ${WORKDIR}/lib
		mkdir ${WORKDIR}/cache
		mkdir ${S}/temp
	
		einfo "Starting to compile kernel..."
		cp ${FILESDIR}/${PF/-r0/}-${ARCH}.config ${WORKDIR}/config || die "cannot copy kernel config"
	
		if use grub; then
			if [ -e "/boot/grub/grub.conf" ]; then
				cp /boot/grub/grub.conf ${WORKDIR}/boot/grub -p
			fi
		fi

		# do some cleanup
		rm -rf "${WORKDIR}"/lib
		rm -rf "${WORKDIR}"/cache
		rm -rf "${S}"/temp
		OLDARCH=${ARCH}
		unset ARCH
		cd ${S}
		GK_ARGS=""
		use splash && GKARGS="${GKARGS} --splash=sabayon"
		use dmraid && GKARGS="${GKARGS} --dmraid"
		use grub && GKARGS="${GKARGS} --bootloader=grub"
		export DEFAULT_KERNEL_SOURCE="${S}"
		export CMD_KERNEL_DIR="${S}"
		DEFAULT_KERNEL_SOURCE="${S}" CMD_KERNEL_DIR="${S}" genkernel ${GKARGS} \
			--kerneldir=${S} \
			--kernel-config=${WORKDIR}/config \
			--cachedir=${WORKDIR}/cache \
			--makeopts=-j3 \
			--tempdir=${S}/temp \
			--logfile=${WORKDIR}/genkernel.log \
			--bootdir=${WORKDIR}/boot \
			--mountboot \
			--lvm \
			--luks \
			--module-prefix=${WORKDIR}/lib \
			all || die "genkernel failed"
		ARCH=${OLDARCH}

	fi
}

src_install() {

	if ! use no_sources || use only_sources; then
		kernel-2_src_install || die "sources install failed"
		if ! use only_sources; then
			cd ${D}/usr/src/linux-${KV_FULL} || die "cannot cd into sources directory"
			OLDARCH=${ARCH}
			unset ARCH
			make distclean || die "cannot run make distclean"
			cp ${FILESDIR}/${PF/-r0/}-${OLDARCH}.config ${D}/usr/src/linux-${KV_FULL}/.config || die "cannot copy kernel configuration"
			make prepare modules_prepare || die "cannot run make prepare modules_prepare"
			ARCH=${OLDARCH}
		fi
	fi

	if ! use only_sources; then
		insinto /boot
		doins ${WORKDIR}/boot/*
		cp -Rp ${WORKDIR}/lib/* ${D}/
		rm ${D}/lib/modules/${KV_FULL}/source
		rm ${D}/lib/modules/${KV_FULL}/build
		ln -s /usr/src/linux-${KV_FULL} ${D}/lib/modules/${KV_FULL}/source
		ln -s /usr/src/linux-${KV_FULL} ${D}/lib/modules/${KV_FULL}/build
		if use grub; then
			if [ -e "${WORKDIR}/boot/grub.conf" ]; then
				insinto /boot/grub/
				doins ${WORKDIR}/boot/grub.conf
			fi
		fi
	fi
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "Please report kernel bugs at:"
	einfo "http://bugs.sabayonlinux.org"
}
