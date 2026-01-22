# Homebrew formula template for radp-vagrant-framework
# The CI workflow uses this template and replaces placeholders with actual values.
#
# Placeholders:
#   %%TARBALL_URL%% - GitHub archive URL for the release tag
#   %%SHA256%%      - SHA256 checksum of the tarball
#   %%VERSION%%     - Version number (without 'v' prefix)
#
# Installation:
#   brew tap xooooooooox/radp
#   brew install radp-vagrant-framework

class RadpVagrantFramework < Formula
  desc "YAML-driven framework for managing multi-machine Vagrant environments"
  homepage "https://github.com/xooooooooox/radp-vagrant-framework"
  url "%%TARBALL_URL%%"
  sha256 "%%SHA256%%"
  version "%%VERSION%%"
  license "MIT"

  # Use system ruby on macOS instead of forcing Homebrew's ruby
  uses_from_macos "ruby"

  # Vagrant is required (installed via cask)
  depends_on cask: "vagrant"

  def install
    # Install Ruby framework files
    libexec.install Dir["src/main/ruby/*"]

    # Install CLI script to libexec/bin and create symlink
    (libexec/"bin").install "src/main/shell/bin/radp-vf"
    bin.install_symlink libexec/"bin/radp-vf"
  end

  def caveats
    <<~EOS
      radp-vagrant-framework requires a Vagrant provider (e.g., VirtualBox).
      To install VirtualBox:
        brew install --cask virtualbox

      Quick start:
        radp-vf init myproject
        cd myproject
        radp-vf vg status
    EOS
  end

  test do
    system "#{bin}/radp-vf", "version"
  end
end
