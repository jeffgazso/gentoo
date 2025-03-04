# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

GENQMAIL_PV=20200817
QMAIL_SPP_PV=0.42

QMAIL_TLS_PV=20200107
QMAIL_TLS_F=notqmail-1.08-tls-${QMAIL_TLS_PV}.patch

QMAIL_BIGTODO_F=notqmail-1.08-big-todo.patch

QMAIL_LARGE_DNS="qmail-103.patch"

inherit qmail systemd

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="https://github.com/notqmail/notqmail.git"
	inherit git-r3
else
	inherit verify-sig
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sparc ~x86"
	SRC_URI="
		https://github.com/notqmail/notqmail/releases/download/${P}/${P}.tar.xz
		verify-sig? (
			https://github.com/notqmail/notqmail/releases/download/${P}/${P}.tar.xz.sig
		)
	"
fi

DESCRIPTION="Collaborative open-source successor to qmail"
HOMEPAGE="
	https://notqmail.org
	https://cr.yp.to/qmail.html
	http://qmail.org
"
SRC_URI="${SRC_URI}
	https://github.com/DerDakon/genqmail/releases/download/genqmail-${GENQMAIL_PV}/${GENQMAIL_F}
	https://www.ckdhr.com/ckd/${QMAIL_LARGE_DNS}
	!vanilla? (
		highvolume? (
			https://github.com/notqmail/notqmail/commit/3a22b45974ddd1230da0dfa21f886c3401bee020.patch -> ${QMAIL_BIGTODO_F}
		)
		qmail-spp? (
			ssl? (
				https://github.com/notqmail/notqmail/commit/c467ba6880aaecfe1d3f592a7738de88cb5ac79a.patch -> ${PN}-1.08-auth.patch
				https://github.com/notqmail/notqmail/commit/d950cc34491afe90432cafcaeda61d1c1a9508e9.patch -> ${PN}-1.08-tls-spp.patch
			)
			!ssl? (
				https://github.com/notqmail/notqmail/commit/b36d52a0dd7315a969f2a9a7455717466e45be23.patch -> ${PN}-1.08-spp.patch
			)
		)
		ssl? (
			https://github.com/notqmail/notqmail/commit/0dc6a3aa9cb3440fe589ca5384ea27d683f05625.patch -> ${QMAIL_TLS_F}
		)
		!ssl? (
			https://github.com/notqmail/notqmail/commit/c467ba6880aaecfe1d3f592a7738de88cb5ac79a.patch -> ${PN}-1.08-auth.patch
		)
	)
"

VERIFY_SIG_OPENPGP_KEY_PATH=${BROOT}/usr/share/openpgp-keys/notqmail.asc

LICENSE="public-domain"
SLOT="0"
IUSE="gencertdaily highvolume pop3 qmail-spp ssl test vanilla"
REQUIRED_USE="vanilla? ( !ssl !qmail-spp !highvolume !gencertdaily ) gencertdaily? ( ssl )"
RESTRICT="!test? ( test )"

if [[ ${PV} != 9999 ]] ; then
	BDEPEND="verify-sig? ( sec-keys/openpgp-keys-notqmail )"
fi
DEPEND="
	net-dns/libidn2
	net-mail/queue-repair
	sys-apps/gentoo-functions
	ssl? ( >=dev-libs/openssl-1.1:0= )
	test? ( dev-libs/check )
"
RDEPEND="${DEPEND}
	acct-group/nofiles
	acct-group/qmail
	acct-user/alias
	acct-user/qmaild
	acct-user/qmaill
	acct-user/qmailp
	acct-user/qmailq
	acct-user/qmailr
	acct-user/qmails
	sys-apps/ucspi-tcp
	ssl? (
		pop3? ( sys-apps/ucspi-ssl )
	)
	!mail-mta/courier
	!mail-mta/esmtp
	!mail-mta/exim
	!mail-mta/msmtp[mta]
	!mail-mta/nullmailer
	!mail-mta/opensmtpd
	!mail-mta/postfix
	!mail-mta/qmail-ldap
	!mail-mta/netqmail
	!mail-mta/sendmail
	!mail-mta/ssmtp[mta]
"
PDEPEND="
	virtual/daemontools
"

src_unpack() {
	genqmail_src_unpack

	[[ ${PV} == "9999" ]] && git-r3_src_unpack
	if [[ ${PV} != "9999" ]]; then
		default
		if use verify-sig; then
			verify-sig_verify_detached "${DISTDIR}"/${P}.tar.xz{,.sig}
		fi
	fi
}

PATCHES=(
	"${DISTDIR}/${QMAIL_LARGE_DNS}"
)

src_prepare() {
	if ! use vanilla; then
		if use qmail-spp; then
			PATCHES+=( "${DISTDIR}/${P}-auth.patch" )
		elif use ssl; then
			PATCHES+=( "${DISTDIR}/${QMAIL_TLS_F}" )
		else
			PATCHES+=( "${DISTDIR}/${P}-auth.patch" )
		fi
		use highvolume && PATCHES+=( "${DISTDIR}/${QMAIL_BIGTODO_F}" )

		if use qmail-spp; then
			if use ssl; then
				PATCHES+=( "${DISTDIR}/${PN}-1.08-tls-spp.patch" )
			else
				PATCHES+=( "${DISTDIR}/${PN}-1.08-spp.patch" )
			fi
		fi
	fi

	default

	qmail_src_postunpack

	einfo "Enabled CRAM_MD5 support"

	ht_fix_file Makefile*
}

src_compile() {
	qmail_src_compile NROFF=true
	emake qmail-send.service
	use qmail-spp && qmail_spp_src_compile
}

src_install() {
	qmail_src_install
	systemd_dounit "${S}"/qmail-send.service
}

src_test() {
	emake test
}

pkg_postinst() {
	qmail_queue_setup
	qmail_rootmail_fixup
	qmail_tcprules_build

	qmail_config_notice
	qmail_supervise_config_notice
	elog
	elog "If you are looking for documentation, check those links:"
	elog "https://wiki.gentoo.org/wiki/Virtual_mail_hosting_with_qmail"
	elog "  -- qmail/vpopmail Virtual Mail Hosting System Guide"
	elog "http://www.lifewithqmail.com/"
	elog "  -- Life with qmail"
	elog
}

pkg_config() {
	# avoid some weird locale problems
	export LC_ALL=C

	qmail_config_fast
	qmail_tcprules_config
	qmail_tcprules_build

	use ssl && qmail_ssl_generate
}
