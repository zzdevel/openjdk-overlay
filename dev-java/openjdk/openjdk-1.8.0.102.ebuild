# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit java-pkg-2 java-vm-2 versionator

DESCRIPTION="OpenJDK"
HOMEPAGE="http://openjdk.java.net/projects/jdk8/"

jdk_major="$( get_version_component_range 2 "${PV}" )"
jdk_update="$( get_version_component_range 4 "${PV}" )"

jdk_project_base="jdk${jdk_major}u"

#### this needs to be updated manually with new version ####

jdk_b="14"

# set to ${jdk_project_base} if project does not have required version
jdk_project_aarch32_port="aarch32-port"
jdk_project_aarch64_port="aarch64-port"

# set to blank if project does not have required version (or has no pre/suffix)
jdk_aarch32_port_suffix="-aarch32-160812"
jdk_aarch64_port_prefix="aarch64-"

############################################################

jdk_tag_base="jdk${jdk_major}u${jdk_update}-b${jdk_b}"
jdk_tag_aarch32_port="${jdk_tag_base}${jdk_aarch32_port_suffix}"
jdk_tag_aarch64_port="${jdk_aarch64_port_prefix}${jdk_tag_base}"

jdk_subprojects="corba hotspot jaxp jaxws jdk langtools nashorn"

function generate_uris {
    local projectName="${1}"
    local tag="${2}"

    local jdk_base_uri="http://hg.openjdk.java.net/${projectName}/jdk${jdk_major}u"
    echo "${jdk_base_uri}/archive/${tag}.tar.bz2 -> ${P}-${projectName}.tar.bz2"
    for subproject in ${jdk_subprojects} ; do
        echo "${jdk_base_uri}/${subproject}/archive/${tag}.tar.bz2 -> ${P}-${projectName}-${subproject}.tar.bz2"
    done
}

SRC_URI="!aarch32-port? ( !aarch64-port? ( $( generate_uris "${jdk_project_base}" "${jdk_tag_base}" ) ) )
    aarch32-port? ( $( generate_uris "${jdk_project_aarch32_port}" "${jdk_tag_aarch32_port}" ) )
    aarch64-port? ( $( generate_uris "${jdk_project_aarch64_port}" "${jdk_tag_aarch64_port}" ) )"

LICENSE="GPL-2-with-linking-exception"
SLOT="$( get_version_component_range 1-2 "${PV}" )"
KEYWORDS="~x86 ~amd64 ~arm ~arm64"

IUSE="+cacerts doc source examples webstart nsplugin aarch32-port aarch64-port"

REQUIRED_USE="aarch32-port? ( arm ) aarch64-port? ( arm64 )"

COMMON_DEP=">=media-libs/alsa-lib-0.9.1
    >=media-libs/freetype-2.3
    net-print/cups
    x11-libs/libX11
    x11-libs/libXext
    x11-libs/libXi
    x11-libs/libXt
    x11-libs/libXtst
    x11-libs/libXrender
    x11-proto/xproto
    x11-proto/inputproto
    x11-proto/randrproto
    sys-libs/zlib
    media-libs/giflib
    cacerts? ( app-misc/ca-certificates )"

RDEPEND="${COMMON_DEP}"

DEPEND="|| (
        >=dev-java/openjdk-1.7
        >=dev-java/oracle-jdk-bin-1.7
        >=dev-java/icedtea-7
        >=dev-java/icedtea-bin-7
        )
    app-arch/cpio
    sys-apps/gawk
    sys-apps/file
    app-arch/zip
    app-arch/unzip
    sys-process/procps
    dev-libs/openssl
    ${COMMON_DEP}"

PDEPEND="webstart? ( dev-java/icedtea-web:0[icedtea7] )
    nsplugin? ( dev-java/icedtea-web:0[icedtea7,nsplugin] )"

function get_jdk_tag_name {
    if use aarch32-port ; then
        echo -n "${jdk_tag_aarch32_port}"
    elif use aarch64-port ; then
        echo -n "${jdk_tag_aarch64_port}"
    else
        echo -n "${jdk_tag_base}"
    fi
}

jit_use_flags="x86 amd64 aarch64-port"

function supports_JIT {
    local flag
    for flag in ${jit_use_flags} ; do
        use "${flag}" && return 0
    done
    return 1
}


pkg_setup(){
    JAVA_PKG_WANT_SOURCE="1.7"
    JAVA_PKG_WANT_TARGET="1.7"

    addpredict "/dev/random"
    addpredict "/dev/urandom"
    addpredict "/proc/self/coredump_filter"

    java-vm-2_pkg_setup
    java-pkg-2_pkg_setup
}

src_unpack() {
    local jdk_tag_name="$( get_jdk_tag_name )"

    unpack ${A}
    mv "jdk8u-${jdk_tag_name}" "${P}"

    for subproject in ${jdk_subprojects} ; do
        mv "${subproject}-${jdk_tag_name}" "${P}/${subproject}"
    done
}

src_configure() {
    local conf_args=""
    if ! supports_JIT ; then
        if use aarch32-port ; then
            conf_args="--with-jvm-variants=core"
        else
            conf_args="--with-jvm-variants=zero"
        fi
    fi

    export LANG=C

    chmod +x ./configure
    econf ${conf_args} \
    --with-milestone="fcs" \
    --with-update-version=${jdk_update} \
    --with-build-number=b${jdk_b} \
    --with-stdc++lib=dynamic \
    --with-zlib=system \
    --with-giflib=system \
    --disable-debug-symbols \
    --disable-zip-debug-info \
    --with-debug-level=release \
    --enable-unlimited-crypto
}

src_compile() {
    emake -j1 all
}

src_install() {
    local jdk_src="$( echo -n ${S}/build/*/images/j2sdk-image )"
    [ -d "${jdk_src}" ] || die "j2sdk-image directory is missing"

    local jdk_prefix="/usr/$(get_libdir)"
    local jdk_path="${EPREFIX}${jdk_prefix}/${PN}-${SLOT}"
    local jdk_dest="${D%/}${jdk_path}"

    local doc_files="ASSEMBLY_EXCEPTION LICENSE release THIRD_PARTY_README"
    for doc in ${doc_files} ; do
        dodoc "${jdk_src}/${doc}"
        rm "${jdk_src}/${doc}"
    done

    if use doc ; then
        local jdk_javadoc_src="$( echo -n ${S}/build/*/docs )"
        [ -d "${jdk_javadoc_src}" ] || die "docs directory is missing"

        for doc in "${jdk_javadoc_src}"/* ; do
            dohtml -r "${doc}"
        done
        dosym "/usr/share/doc/${PF}" "/usr/share/doc/${PN}-${SLOT}"
    fi

    if ! use source ; then
        rm "${jdk_src}"/src.zip
    fi

    if ! use examples ; then
        rm -rf "${jdk_src}"/demo "${jdk_src}"/sample
    fi

    # use non-blocking /dev/urandom instead of /dev/random
    sed -i 's;securerandom.source=file:/dev/random;securerandom.source=file:/dev/./urandom;g' \
    "${jdk_src}"/jre/lib/security/java.security || die

    # use cacerts updater script
    if use cacerts ; then
        local tmpCertsUpdater="${T}/${PN}-${SLOT}-cacerts-updater"
        cp "${FILESDIR}/cacerts-updater" "${tmpCertsUpdater}"
        sed -i "s;@JAVA_HOME@;${jdk_path};g" "${tmpCertsUpdater}"
        sed -i "s;@SLOT@;${SLOT};g" "${tmpCertsUpdater}"
        exeinto /etc/ca-certificates/update.d
        doexe "${tmpCertsUpdater}"
    fi

    dodir ${jdk_prefix}
    cp -RPp "${jdk_src}" "${jdk_dest}"

    if use webstart || use nsplugin; then
        dosym /usr/libexec/icedtea-web/itweb-settings "/usr/$(get_libdir)/${PN}-${SLOT}/bin/itweb-settings"
        dosym /usr/libexec/icedtea-web/itweb-settings "/usr/$(get_libdir)/${PN}-${SLOT}/jre/bin/itweb-settings"
    fi
    if use webstart; then
        dosym /usr/libexec/icedtea-web/javaws "/usr/$(get_libdir)/${PN}-${SLOT}/bin/javaws"
        dosym /usr/libexec/icedtea-web/javaws "/usr/$(get_libdir)/${PN}-${SLOT}/jre/bin/javaws"
    fi

    set_java_env
    java-vm_sandbox-predict /dev/random /dev/urandom /proc/self/coredump_filter
}

pkg_postinst() {
    if use cacerts ; then
        update-ca-certificates
    fi
}

