# Homebrew formula for radp-vagrant-framework
# This is a template - actual formula is in the homebrew-radp tap
#
# Installation:
#   brew tap xooooooooox/radp
#   brew install radp-vagrant-framework

class RadpVagrantFramework < Formula
  desc "YAML-driven framework for managing multi-machine Vagrant environments"
  homepage "https://github.com/xooooooooox/radp-vagrant-framework"
  url "https://github.com/xooooooooox/radp-vagrant-framework/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  version "0.1.0"
  license "MIT"

  depends_on "ruby"

  def install
    # Install framework files to libexec
    libexec.install Dir["src/main/ruby/*"]

    # Create wrapper script
    (bin/"radp-vf").write <<~EOS
      #!/bin/bash
      export RADP_VF_HOME="#{libexec}"
      cd "#{libexec}" && exec ruby -r ./lib/radp_vagrant -e "
        case ARGV[0]
        when 'version', '-v', '--version'
          puts RadpVagrant::VERSION
        when 'dump-config'
          filter = ARGV[1]
          RadpVagrant.dump_config('config', filter)
        when 'generate'
          output = ARGV[1]
          if output
            RadpVagrant.generate_vagrantfile('config', output)
          else
            puts RadpVagrant.generate_vagrantfile('config')
          end
        else
          puts 'Usage: radp-vf <command>'
          puts 'Commands: version, dump-config [filter], generate [output]'
        end
      " -- "$@"
    EOS
  end

  test do
    system "#{bin}/radp-vf", "version"
  end
end
