bin_PROGRAMS = maqval
maqval_SOURCES = main.c ovc_test.c bfa.c dedup.c ov.c maqmap.c snplist.c
maqval_LDADD = -lm
lib_LTLIBRARIES=libmaqval.la
libmaqval_la_SOURCES=ovc_test.c bfa.c dedup.c ov.c maqmap.c snplist.c

maqval.o:bfa.h const.h dedup.h ov.h maqmap.h snplist.h
