# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit java-pkg-2 java-vm-2 versionator

DESCRIPTION="OpenJDK"
HOMEPAGE="https://openjdk.java.net/projects/jdk8u/"

jdk_major="$( get_version_component_range 2 "${PV}" )"
jdk_update="$( get_version_component_range 4 "${PV}" )"

jdk_project_base="jdk${jdk_major}u"

#### this needs to be updated manually with new version ####

jdk_b="12"

# set to ${jdk_project_base} if project does not have required version (tag)
jdk_project_aarch32_port="aarch32-port"
jdk_project_aarch64_port_shenandoah="aarch64-port"

# set to blank if project does not have required tag (or there is no pre/suffix)
jdk_tag_suffix_aarch32_port="-aarch32-181022"
jdk_tag_prefix_aarch64_port_shenandoah="aarch64-shenandoah-"

############################################################

jdk_tag_base="${jdk_project_base}${jdk_update}-b${jdk_b}"
jdk_tag_aarch32_port="${jdk_tag_base}${jdk_tag_suffix_aarch32_port}"
jdk_tag_aarch64_port_shenandoah="${jdk_tag_prefix_aarch64_port_shenandoah}${jdk_tag_base}"

jdk_forest_base="${jdk_project_base}"
jdk_forest_aarch32_port="${jdk_forest_base}"
jdk_forest_aarch64_port_shenandoah="${jdk_forest_base}-shenandoah"

jdk_subprojects="corba hotspot jaxp jaxws jdk langtools nashorn"

generate_uris() {
    local projectName="${1}"
    local forestName="${2}"
    local tag="${3}"

    local jdk_base_uri="http://hg.openjdk.java.net/${projectName}/${forestName}"
    printf '%s\n' "${jdk_base_uri}/archive/${tag}.tar.bz2 -> ${P}_${projectName}_${forestName}_${tag}.tar.bz2"
    for subproject in ${jdk_subprojects} ; do
        printf '%s\n' "${jdk_base_uri}/${subproject}/archive/${tag}.tar.bz2 -> ${P}_${projectName}_${forestName}_${subproject}_${tag}.tar.bz2"
    done
}

SRC_URI="!aarch32-port? ( !aarch64-port-shenandoah? ( $( generate_uris "${jdk_project_base}" "${jdk_forest_base}" "${jdk_tag_base}" ) ) )
    aarch32-port? ( $( generate_uris "${jdk_project_aarch32_port}" "${jdk_forest_aarch32_port}" "${jdk_tag_aarch32_port}" ) )
    aarch64-port-shenandoah? ( $( generate_uris "${jdk_project_aarch64_port_shenandoah}" "${jdk_forest_aarch64_port_shenandoah}" "${jdk_tag_aarch64_port_shenandoah}" ) )"

LICENSE="GPL-2-with-linking-exception"
SLOT="$( get_version_component_range 1-2 "${PV}" )"
KEYWORDS="~x86 ~amd64 ~arm ~arm64"

IUSE="+cacerts doc source examples aarch32-port aarch64-port-shenandoah pax_kernel"

REQUIRED_USE="aarch32-port? ( !aarch64-port-shenandoah ) aarch64-port-shenandoah? ( !aarch32-port )"

COMMON_DEP=">=media-libs/alsa-lib-0.9.1
    >=media-libs/freetype-2.3
    net-print/cups
    x11-libs/libX11
    x11-libs/libXext
    x11-libs/libXi
    x11-libs/libXt
    x11-libs/libXtst
    x11-libs/libXrender
    x11-base/xorg-proto
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
    pax_kernel? ( sys-apps/paxctl )
    ${COMMON_DEP}"


get_forest_name() {
    if use aarch32-port ; then
       printf '%s' "${jdk_forest_aarch32_port}"
    elif use aarch64-port-shenandoah ; then
       printf '%s' "${jdk_forest_aarch64_port_shenandoah}"
    else
       printf '%s' "${jdk_forest_base}"
    fi
}

get_tag_name() {
    if use aarch32-port ; then
        printf '%s' "${jdk_tag_aarch32_port}"
    elif use aarch64-port-shenandoah ; then
        printf '%s' "${jdk_tag_aarch64_port_shenandoah}"
    else
        printf '%s' "${jdk_tag_base}"
    fi
}

jit_archs="x86 amd64"

supports_JIT_C2() {
    use arm64 && use aarch64-port-shenandoah && return 0
    local arch
    for arch in ${jit_archs} ; do
        use "${arch}" && return 0
    done
    return 1
}

supports_JIT_C1() {
    use arm && use aarch32-port && return 0
    return 1
}


pkg_setup() {
    # seen in icedtea ( is it needed? )
    JAVA_PKG_WANT_SOURCE="1.7"
    JAVA_PKG_WANT_TARGET="1.7"

    use aarch32-port && [ "${jdk_project_aarch32_port}" = "${jdk_project_base}" ] && die "${PN} version ${PV} is not available for aarch32 port"
    use aarch64-port-shenandoah && [ "${jdk_project_aarch64_port_shenandoah}" = "${jdk_project_base}" ] && die "${PN} version ${PV} is not available for aarch64 shanandoah port"

    addpredict "/dev/random"
    addpredict "/dev/urandom"
    addpredict "/proc/self/coredump_filter"

    java-vm-2_pkg_setup
    java-pkg-2_pkg_setup
}

src_unpack() {
    unpack ${A}

    local jdk_forest="$( get_forest_name )"
    local jdk_tag="$( get_tag_name )"

    mv "${jdk_forest}-${jdk_tag}" "${P}"
    for subproject in ${jdk_subprojects} ; do
        mv "${subproject}-${jdk_tag}" "${P}/${subproject}"
    done
}

src_configure() {
    local conf_args=""
    if ! supports_JIT_C2 ; then
        if supports_JIT_C1 ; then
            conf_args="--with-jvm-variants=client"
        else
            conf_args="--with-jvm-variants=zero"
        fi
    fi

    chmod +x ./configure
    LANG=C econf ${conf_args} \
    --with-milestone="fcs" \
    --with-update-version=${jdk_update} \
    --with-build-number=b${jdk_b} \
    --with-stdc++lib=dynamic \
    --with-zlib=system \
    --with-giflib=system \
    --enable-debug-symbols \
    --disable-zip-debug-info \
    --with-debug-level=release \
    --enable-unlimited-crypto \
    --with-extra-cflags="-Wno-error" \
    --with-extra-cxxflags="-Wno-error"
}

src_compile() {
    LANG=C LC_ALL=C emake -j1 all
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

    java-vm_set-pax-markings "${jdk_dest}"

    if supports_JIT_C2 ; then
        if use x86 ; then
            ${jdk_dest}/bin/java -client -Xshare:dump || die
            # limit heap size for large memory on x86 #467518
            # this is a workaround and shouldn't be needed.
            ${jdk_dest}/bin/java -server -Xms64m -Xmx64m -Xshare:dump || die
        else
            if ! use ppc64 && ! use ppc ; then
                ${jdk_dest}/bin/java -server -Xshare:dump || die
            fi
        fi
    else
        if supports_JIT_C1 ; then
            ${jdk_dest}/bin/java -client -Xshare:dump || die
        fi
    fi

    set_java_env
    java-vm_sandbox-predict /dev/random /dev/urandom /proc/self/coredump_filter
}

pkg_postinst() {
    if use cacerts ; then
        update-ca-certificates
    fi
}
