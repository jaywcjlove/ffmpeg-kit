lib_LTLIBRARIES = libffmpegkit.la

libffmpegkit_la_LIBADD = @FFMPEG_FRAMEWORKS@

libffmpegkit_la_SOURCES = \
    ffmpegkit_runtime.c \
    fftools_cmdutils.c \
    fftools_ffmpeg.c \
    fftools_ffmpeg_demux.c \
    fftools_ffmpeg_filter.c \
    fftools_ffmpeg_hw.c \
    fftools_ffmpeg_mux.c \
    fftools_ffmpeg_mux_init.c \
    fftools_ffmpeg_opt.c \
    fftools_ffprobe.c \
    fftools_objpool.c \
    fftools_opt_common.c \
    fftools_sync_queue.c \
    fftools_thread_queue.c

include_HEADERS = \
    fftools_cmdutils.h \
    fftools_ffmpeg.h \
    fftools_ffmpeg_mux.h \
    fftools_fopen_utf8.h \
    fftools_objpool.h \
    fftools_opt_common.h \
    fftools_sync_queue.h \
    fftools_thread_queue.h

libffmpegkit_la_CFLAGS = $(CFLAGS)
libffmpegkit_la_CXXFLAGS = $(CXXFLAGS)
libffmpegkit_la_LDFLAGS = $(LDFLAGS)
