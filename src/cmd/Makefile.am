AM_CFLAGS = @GCCWARN@

fluxbindir = $(libexecdir)/flux
fluxlibdir = $(libdir)/flux
fluxmoddir = $(fluxlibdir)/modules

plugin_path = $(top_builddir)/src/modules/api/.libs:$(top_builddir)/src/modules/kvs/.libs:$(top_builddir)/src/modules/modctl/.libs:$(fluxmoddir)

exec_path = $(top_builddir)/src/cmd:$(fluxbindir)

AM_CPPFLAGS = \
	$(JSON_CFLAGS) \
        -DPLUGIN_PATH=\"$(plugin_path)\" -DEXEC_PATH=\"$(exec_path)\" \
	-I$(top_srcdir)/src/common/libutil \
	-I$(top_srcdir)/src/common/libflux \
	-I$(top_srcdir)/src/modules/api \
	-I$(top_srcdir)/src/modules/kvs \
	-I$(top_srcdir)/src/modules/live \
	-I$(top_srcdir)/src/modules/modctl

bin_PROGRAMS = flux

flux_SOURCES = flux.c
flux_LDADD = \
	$(top_builddir)/src/common/libutil/libutil.la \
	$(LIBZMQ)

#
# Flux subcommands
#

dist_fluxbin_SCRIPTS = \
	srun \
	screen

fluxbin_PROGRAMS = \
	event \
	xinfo \
	keygen \
	kvs \
	kvscopy \
	kvsdir \
	kvstorture \
	kvswatch \
	logger \
	mod \
	peer \
	ping \
	snoop \
	stats \
	up \
	zio

fluxbin_ldadd = \
	$(top_builddir)/src/modules/live/liblive.la \
	$(top_builddir)/src/modules/modctl/libmodctl.la \
	$(top_builddir)/src/modules/kvs/libkvs.la \
	$(top_builddir)/src/modules/api/libapi.la \
	$(top_builddir)/src/common/libflux/libflux.la \
	$(top_builddir)/src/common/libutil/libutil.la \
	$(JSON_LIBS) $(LIBZMQ) $(LIBCZMQ) $(LIBMUNGE) $(LIBPTHREAD)

event_SOURCES = event.c
event_LDADD = $(fluxbin_ldadd)

xinfo_SOURCES = info.c
xinfo_LDADD = $(fluxbin_ldadd)

keygen_SOURCES = keygen.c
keygen_LDADD = $(fluxbin_ldadd)

kvs_SOURCES = kvs.c
kvs_LDADD = $(fluxbin_ldadd)

kvscopy_SOURCES = kvscopy.c
kvscopy_LDADD = $(fluxbin_ldadd)

kvsdir_SOURCES = kvsdir.c
kvsdir_LDADD = $(fluxbin_ldadd)

kvstorture_SOURCES = kvstorture.c
kvstorture_LDADD = $(fluxbin_ldadd)

kvswatch_SOURCES = kvswatch.c
kvswatch_LDADD = $(fluxbin_ldadd)

logger_SOURCES = logger.c
logger_LDADD = $(fluxbin_ldadd)

mod_SOURCES = mod.c
mod_LDADD = $(fluxbin_ldadd)

peer_SOURCES = peer.c
peer_LDADD = $(fluxbin_ldadd)

ping_SOURCES = ping.c
ping_LDADD = $(fluxbin_ldadd)

snoop_SOURCES = snoop.c
snoop_LDADD = $(fluxbin_ldadd)

stats_SOURCES = stats.c
stats_LDADD = $(fluxbin_ldadd)

up_SOURCES = up.c
up_LDADD = $(fluxbin_ldadd)

zio_SOURCES = zio.c
zio_LDADD = \
	$(top_builddir)/src/common/libzio/libzio.la \
	$(top_builddir)/src/common/liblsd/liblsd.la \
	$(fluxbin_ldadd) \
	$(LIBUTIL)
zio_CPPFLAGS = \
	-I$(top_srcdir)/src/common/libzio \
	$(AM_CPPFLAGS)