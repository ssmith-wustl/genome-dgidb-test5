#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.60a)
AC_INIT(MAQVAL, 0.1.0)
AC_CONFIG_SRCDIR([snplist.h])
AC_CONFIG_HEADER([config.h])
AM_INIT_AUTOMAKE([no-dependencies])

AC_CANONICAL_HOST
# Checks for programs.
AC_PROG_CC
AC_PROG_CXX
# Checks for libraries.
AC_PROG_LIBTOOL
AC_SUBST(LIBTOOL_DEPS)

# set CFLAGS
generic_CFLAGS="-g -O2 -Wall `pkg-config glib-2.0 --cflags --libs`"
ext_CFLAGS=""
case "${host}" in
	i[[3456]]86-*-linux*) ext_CFLAGS="-D_FILE_OFFSET_BITS=64";;
  *)
    AC_MSG_CHECKING([if gcc accepts -m64])
    CFLAGS="-m64";;
esac
CFLAGS="${generic_CFLAGS} ${ext_CFLAGS}"

# Checks for libraries.
AC_CHECK_LIB([z], [gzopen])

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([zlib.h stdlib.h string.h unistd.h glib.h])

# Checks for typedefs, structures, and compiler characteristics.
#AC_C_CONST

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_MEMCMP
AC_FUNC_REALLOC

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
