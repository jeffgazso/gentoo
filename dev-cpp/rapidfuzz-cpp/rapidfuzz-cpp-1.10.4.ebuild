# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Rapid fuzzy string matching in C++"
HOMEPAGE="https://github.com/maxbachmann/rapidfuzz-cpp/"
SRC_URI="
	https://github.com/maxbachmann/rapidfuzz-cpp/archive/v${PV}.tar.gz
		-> ${P}.gh.tar.gz
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 arm arm64 ~ia64 ~mips ppc ppc64 ~riscv sparc ~x86"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="
	test? (
		>=dev-cpp/catch-3
	)
"

src_configure() {
	local mycmakeargs=(
		-DRAPIDFUZZ_BUILD_TESTING=$(usex test)
	)
	cmake_src_configure
}
