class Lua53 < Formula
  desc "Powerful, lightweight programming language"
  homepage "http://www.lua.org/"
  url "http://www.lua.org/ftp/lua-5.3.1.tar.gz"
  mirror "https://raw.githubusercontent.com/DomT4/LibreMirror/master/Lua/lua-5.3.1.tar.gz"
  sha256 "072767aad6cc2e62044a66e8562f51770d941e972dc1e4068ba719cd8bffac17"
  revision 1

  bottle do
    cellar :any
    sha256 "098149cc98267efa4398ee2a64c64ea5e6844841d6d3ec1f559c9d1df7074155" => :yosemite
    sha256 "bded0d9a5d6c56a1885121730c1532c35fccb0282e17afde91ecfb0eadf2ac34" => :mavericks
    sha256 "366063708800ef98a4d9f2501b922fa197771055445587aa467d7ea0fb01e3cf" => :mountain_lion
  end

  fails_with :llvm do
    build 2326
    cause "Lua itself compiles with LLVM, but may fail when other software tries to link."
  end

  option :universal
  option "with-default-names", "Don't version-suffix the Lua installation. Conflicts with Homebrew's Lua"
  option "without-luarocks", "Don't build with Luarocks support embedded"

  # Be sure to build a dylib, or else runtime modules will pull in another static copy of liblua = crashy
  # See: https://github.com/Homebrew/homebrew/pull/5043
  # ***Update me with each version bump!***
  patch :DATA

  resource "luarocks" do
    url "https://keplerproject.github.io/luarocks/releases/luarocks-2.2.2.tar.gz"
    sha256 "4f0427706873f30d898aeb1dfb6001b8a3478e46a5249d015c061fe675a1f022"
  end

  def install
    ENV.universal_binary if build.universal?

    # Use our CC/CFLAGS to compile.
    inreplace "src/Makefile" do |s|
      s.remove_make_var! "CC"
      s.change_make_var! "CFLAGS", "#{ENV.cflags} -DLUA_COMPAT_ALL $(SYSCFLAGS) $(MYCFLAGS)"
      s.change_make_var! "MYLDFLAGS", ENV.ldflags
    end

    # Fix path in the config header
    inreplace "src/luaconf.h", "/usr/local", HOMEBREW_PREFIX

    # We ship our own pkg-config file as Lua no longer provide them upstream.
    system "make", "macosx", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}", "INSTALL_INC=#{include}/lua-5.3"
    system "make", "install", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}", "INSTALL_INC=#{include}/lua-5.3"
    (lib+"pkgconfig/lua.pc").write pc_file
    include.install_symlink "lua-5.3" => "lua5.3"

    # Allows side-by-side-by-side-by-side Lua installations
    if build.without? "default-names"
      mv "#{bin}/lua", "#{bin}/lua-5.3"
      mv "#{bin}/luac", "#{bin}/luac-5.3"
      mv "#{man1}/lua.1", "#{man1}/lua-5.3.1"
      mv "#{man1}/luac.1", "#{man1}/luac-5.3.1"
      mv "#{lib}/pkgconfig/lua.pc", "#{lib}/pkgconfig/lua5.3.pc"

      bin.install_symlink "lua-5.3" => "lua5.3"
      bin.install_symlink "luac-5.3" => "luac5.3"
      (lib/"pkgconfig").install_symlink "lua5.3.pc" => "lua-5.3.pc"

      # Patches the pkg-config file to find the correct lib names
      inreplace lib/"pkgconfig/lua5.3.pc", "Libs: -L${libdir} -llua -lm", "Libs: -L${libdir} -llua5.3 -lm"
    end

    # This resource must be handled after the main install, since there's a lua dep.
    # Keeping it in install rather than postinstall means we can bottle.
    if build.with? "luarocks"
      resource("luarocks").stage do
        ENV.prepend_path "PATH", bin
        lua_prefix = prefix

        system "./configure", "--prefix=#{libexec}", "--rocks-tree=#{HOMEBREW_PREFIX}",
                              "--sysconfdir=#{etc}/luarocks53", "--with-lua=#{lua_prefix}",
                              "--lua-version=5.3", "--versioned-rocks-dir"
        system "make", "build"
        system "make", "install"

        (share/"lua/5.3/luarocks").install_symlink Dir["#{libexec}/share/lua/5.3/luarocks/*"]
        bin.install_symlink libexec/"bin/luarocks-5.3"
        bin.install_symlink libexec/"bin/luarocks-admin-5.3"

        # This block ensures luarock exec scripts don't break across updates.
        inreplace libexec/"share/lua/5.3/luarocks/site_config.lua" do |s|
          s.gsub! libexec.to_s, opt_libexec
          s.gsub! include.to_s, "#{HOMEBREW_PREFIX}/include"
          s.gsub! lib.to_s, "#{HOMEBREW_PREFIX}/lib"
          s.gsub! bin.to_s, "#{HOMEBREW_PREFIX}/bin"
        end
      end
    end
  end

  def pc_file; <<-EOS.undent
    V= 5.3
    R= 5.3.1
    prefix=#{HOMEBREW_PREFIX}
    INSTALL_BIN= ${prefix}/bin
    INSTALL_INC= ${prefix}/include/lua-5.3
    INSTALL_LIB= ${prefix}/lib
    INSTALL_MAN= ${prefix}/share/man/man1
    INSTALL_LMOD= ${prefix}/share/lua/${V}
    INSTALL_CMOD= ${prefix}/lib/lua/${V}
    exec_prefix=${prefix}
    libdir=${exec_prefix}/lib
    includedir=${prefix}/include/lua-5.3

    Name: Lua
    Description: An Extensible Extension Language
    Version: 5.3.1
    Requires:
    Libs: -L${libdir} -llua -lm
    Cflags: -I${includedir}
    EOS
  end

  test do
    system "#{bin}/lua-5.3", "-e", "print ('Ducks are cool')"
  end
end

__END__
diff --git a/Makefile b/Makefile
index 7fa91c8..a825198 100644
--- a/Makefile
+++ b/Makefile
@@ -41,7 +41,7 @@ PLATS= aix bsd c89 freebsd generic linux macosx mingw posix solaris
 # What to install.
 TO_BIN= lua luac
 TO_INC= lua.h luaconf.h lualib.h lauxlib.h lua.hpp
-TO_LIB= liblua.a
+TO_LIB= liblua.5.3.1.dylib
 TO_MAN= lua.1 luac.1

 # Lua version and release.
@@ -63,6 +63,7 @@ install: dummy
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
	cd doc && $(INSTALL_DATA) $(TO_MAN) $(INSTALL_MAN)
+	ln -s -f liblua.5.3.1.dylib $(INSTALL_LIB)/liblua.5.3.dylib

 uninstall:
	cd src && cd $(INSTALL_BIN) && $(RM) $(TO_BIN)
diff --git a/src/Makefile b/src/Makefile
index 2e7a412..d0c4898 100644
--- a/src/Makefile
+++ b/src/Makefile
@@ -28,7 +28,7 @@ MYOBJS=

 PLATS= aix bsd c89 freebsd generic linux macosx mingw posix solaris

-LUA_A=	liblua.a
+LUA_A=	liblua.5.3.1.dylib
 CORE_O=	lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o \
	lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o \
	ltm.o lundump.o lvm.o lzio.o
@@ -56,11 +56,12 @@ o:	$(ALL_O)
 a:	$(ALL_A)

 $(LUA_A): $(BASE_O)
-	$(AR) $@ $(BASE_O)
-	$(RANLIB) $@
+	$(CC) -dynamiclib -install_name HOMEBREW_PREFIX/lib/liblua.5.3.dylib \
+		-compatibility_version 5.3 -current_version 5.3.1 \
+		-o liblua.5.3.1.dylib $^

 $(LUA_T): $(LUA_O) $(LUA_A)
-	$(CC) -o $@ $(LDFLAGS) $(LUA_O) $(LUA_A) $(LIBS)
+	$(CC) -fno-common $(MYLDFLAGS) -o $@ $(LUA_O) $(LUA_A) -L. -llua.5.3.1 $(LIBS)

 $(LUAC_T): $(LUAC_O) $(LUA_A)
	$(CC) -o $@ $(LDFLAGS) $(LUAC_O) $(LUA_A) $(LIBS)
@@ -110,7 +111,7 @@ linux:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX" SYSLIBS="-Wl,-E -ldl -lreadline"

 macosx:
-	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX" SYSLIBS="-lreadline" CC=cc
+	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" SYSLIBS="-lreadline" CC=cc

 mingw:
	$(MAKE) "LUA_A=lua53.dll" "LUA_T=lua.exe" \