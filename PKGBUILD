# Maintainer: mwarrc <https://github.com/mwarrc>
pkgname=proxyset
pkgver=0.1
pkgrel=1
pkgdesc="Modular proxy configuration manager for system tools, package managers, and dev environments"
arch=('any')
url="https://github.com/mwarrc/proxyset"
license=('MIT')
depends=('bash' 'curl')
optdepends=(
    'git: support for git proxy'
    'docker: support for docker proxy'
    'npm: support for npm proxy'
    'gnupg: audit log signing'
)
source=("https://github.com/mwarrc/proxyset/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('SKIP') #to be replaced with actual checksum when released-(during the release process)

package() {
  cd "$pkgname-$pkgver"
  # Use the Makefile we just created
  make DESTDIR="$pkgdir" PREFIX=/usr install
}
