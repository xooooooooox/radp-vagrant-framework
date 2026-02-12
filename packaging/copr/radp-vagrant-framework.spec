#----------------------------------------------------------------------------------------------------------------------#
# 说明
# 1) Release 与 Version
# - Version: 表示源码版本号,通常与 Git tag/release 一致(比如 v0.2.15 -> 0.2.15)
# - Release: 标识在同一个 Version 下, 打包发布的第几次迭代(这里的迭代一般针对的是 spec 文件的修改)
# 2) changelog 编写规范
# - 第一行格式: * Day Mon DD YYYY Name <email> - Version-Release
# - 第二行以后: 用 -  列出变更点
#----------------------------------------------------------------------------------------------------------------------#

Name:           radp-vagrant-framework
Version:        0.3.10
Release:        1%{?dist}
Summary:        YAML-driven framework for managing multi-machine Vagrant environments

License:        MIT
URL:            https://github.com/xooooooooox/radp-vagrant-framework
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch
Requires:       bash
Requires:       coreutils
Requires:       ruby
Requires:       radp-bash-framework

%description
radp-vagrant-framework is a YAML-driven framework for managing multi-machine
Vagrant environments with configuration inheritance and modular provisioning.

%prep
%setup -q -n radp-vagrant-framework-%{version}

%build
# nothing to build

%install
rm -rf %{buildroot}

# install framework with standard CLI project structure
mkdir -p %{buildroot}%{_libdir}/radp-vagrant-framework

# install bin directory
cp -a bin %{buildroot}%{_libdir}/radp-vagrant-framework/

# install src directory (shell and ruby)
cp -a src %{buildroot}%{_libdir}/radp-vagrant-framework/

# install templates
cp -a templates %{buildroot}%{_libdir}/radp-vagrant-framework/

# Remove IDE support files (development only, not needed at runtime)
find %{buildroot}%{_libdir}/radp-vagrant-framework/src -name "_ide*.sh" -delete

# ensure executables
chmod 0755 %{buildroot}%{_libdir}/radp-vagrant-framework/bin/radp-vf
find %{buildroot}%{_libdir}/radp-vagrant-framework/src/main/shell -type f -name "*.sh" -exec chmod 0755 {} \;

# user-facing commands
mkdir -p %{buildroot}%{_bindir}
ln -s %{_libdir}/radp-vagrant-framework/bin/radp-vf %{buildroot}%{_bindir}/radp-vf

# install shell completions (from root completions/ directory)
mkdir -p %{buildroot}%{_datadir}/bash-completion/completions
mkdir -p %{buildroot}%{_datadir}/zsh/site-functions
cp -a completions/radp-vf.bash %{buildroot}%{_datadir}/bash-completion/completions/radp-vf
cp -a completions/radp-vf.zsh %{buildroot}%{_datadir}/zsh/site-functions/_radp-vf

%post
echo "xooooooooox/radp-vagrant-framework" > %{_libdir}/radp-vagrant-framework/.install-repo
echo "rpm" > %{_libdir}/radp-vagrant-framework/.install-method
echo "v%{version}" > %{_libdir}/radp-vagrant-framework/.install-version

%files
%license LICENSE
%doc README.md
%{_bindir}/radp-vf
%{_libdir}/radp-vagrant-framework/
%{_datadir}/bash-completion/completions/radp-vf
%{_datadir}/zsh/site-functions/_radp-vf

%changelog
* Mon Feb 02 2026 xooooooooox <xozoz.sos@gmail.com> - 0.2.16-1
- Refactor CLI to use radp-bash-framework
- Add COPR and OBS packaging support
