class Permstrap < Formula
  SOURCE_REPOSITORY = Pathname(__dir__).parent.freeze
  VENDORED_SUBPROJECTS = {
    "argtable3" => "argtable3-3.3.1",
    "cc"        => "CC-1.4.3",
    "libsodium" => "libsodium-1.0.22",
    "utf8proc"  => "utf8proc-2.11.3",
    "yyjson"    => "yyjson-0.12.0",
  }.freeze

  desc "Bootstrap macOS Privacy & Security permissions through System Settings"
  homepage "https://github.com/4evy/permstrap"
  url "file://#{SOURCE_REPOSITORY}", using: :git
  version "1.0.0"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on xcode: ["26.0", :build]
  depends_on arch: :arm64
  depends_on macos: :tahoe

  resource "argtable3" do
    url "https://github.com/argtable/argtable3/releases/download/v3.3.1/argtable-v3.3.1-amalgamation.tar.gz"
    sha256 "00eb041bedd84a7e1912e5f8a95d8408350874dca7b46d6ed110bfac44342663"
  end

  resource "cc" do
    url "https://github.com/JacksonAllan/CC/archive/refs/tags/v1.4.3.tar.gz"
    sha256 "88ecc67b2650891707d364a54bf3984927240530a2cdeb296415485dc14b3859"
  end

  resource "libsodium" do
    url "https://github.com/jedisct1/libsodium/releases/download/1.0.22-RELEASE/libsodium-1.0.22.tar.gz"
    sha256 "adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349"
  end

  resource "utf8proc" do
    url "https://github.com/JuliaStrings/utf8proc/releases/download/v2.11.3/utf8proc-2.11.3.tar.gz"
    sha256 "415189fd2c85cd6ee5ff26af500fa387de9ada1e3e316e93f7338551481d557d"
  end

  resource "yyjson" do
    url "https://github.com/ibireme/yyjson/archive/refs/tags/0.12.0.tar.gz"
    sha256 "b16246f617b2a136c78d73e5e2647c6f1de1313e46678062985bdcf1f40bb75d"
  end

  def install
    VENDORED_SUBPROJECTS.each do |resource_name, directory|
      subproject = buildpath/"subprojects"/directory
      stage_path = (resource_name == "argtable3") ? subproject/"dist" : subproject
      resource(resource_name).stage stage_path
      subproject.install(
        (buildpath/"subprojects/packagefiles"/resource_name).children,
      )
    end

    args = %w[
      -Doptimization=3
      -Ddebug=false
      -Ddefault_library=static
      -Dprefer_static=false
      -Dstrip=true
      -Db_lto=true
      -Db_lto_mode=thin
      -Db_ndebug=true
      -Db_pie=true
      -Db_staticpic=true
      -Db_asneeded=true
      -Db_lundef=true
      -Ddeveloper_checks=disabled
    ]
    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose",
           "bundle-application-executable", "application-icon", "permstrap-probe"

    app = buildpath/"build/Permstrap.app"
    app_executable = app/"Contents/MacOS/permstrap"
    rm app/"Contents/Resources/AppIcon.partial.plist"
    system "/usr/bin/strip", "-S", "-x", app_executable
    system "/usr/bin/strip", "-S", "-x", buildpath/"build/permstrap-probe"
    identities = Utils.safe_popen_read(
      "/usr/bin/security", "find-identity", "-v", "-p", "codesigning"
    )
    local_identity = identities[/"([^"]+ Local Code Signing)"/, 1]
    codesign_identity = ENV.fetch("PERMSTRAP_CODESIGN_IDENTITY", local_identity || "-")
    system "/usr/bin/codesign", "--force", "--options", "runtime",
           "--sign", codesign_identity, app
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", app

    prefix.install app
    bin.install buildpath/"build/permstrap-probe"
    bin.write_exec_script prefix/"Permstrap.app/Contents/MacOS/permstrap"
  end

  def caveats
    <<~EOS
      Permstrap.app is installed at:
        #{opt_prefix}/Permstrap.app

      To make the app visible in /Applications, create a symlink:
        ln -sfn #{opt_prefix}/Permstrap.app /Applications/Permstrap.app
    EOS
  end

  test do
    assert_match "permstrap #{version}", shell_output("#{bin}/permstrap --version")
    assert_match "permstrap-probe #{version}", shell_output("#{bin}/permstrap-probe --version")
    assert_path_exists prefix/"Permstrap.app/Contents/Resources/Permissions.json"
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", prefix/"Permstrap.app"
  end
end
