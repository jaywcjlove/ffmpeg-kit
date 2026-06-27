/*
 * Copyright (c) 2018-2021 Taner Sener
 *
 * This file is part of FFmpegKit.
 */

#include "ffmpegkit_exception.h"
#include "ffmpegkit_runtime.h"

#include <stdatomic.h>
#include <stdarg.h>
#include <stdio.h>

#define SESSION_MAP_SIZE 1000

__thread jmp_buf ex_buf__;
__thread long globalSessionId = 0;

volatile int handleSIGQUIT = 1;
volatile int handleSIGINT = 1;
volatile int handleSIGTERM = 1;
volatile int handleSIGXCPU = 1;
volatile int handleSIGPIPE = 1;

static atomic_short sessionMap[SESSION_MAP_SIZE];
static void (*runtime_log_callback)(void *ptr, int level, const char *format, va_list vargs);

void ffmpegkit_set_session_id(long session_id)
{
    globalSessionId = session_id;
    atomic_store(&sessionMap[session_id % SESSION_MAP_SIZE], 0);
}

void ffmpegkit_set_log_callback(void (*callback)(void *ptr, int level, const char *format, va_list vargs))
{
    runtime_log_callback = callback;
}

void cancelSession(long sessionId)
{
    atomic_store(&sessionMap[sessionId % SESSION_MAP_SIZE], 2);
}

int cancelRequested(long sessionId)
{
    return atomic_load(&sessionMap[sessionId % SESSION_MAP_SIZE]) == 2 ? 1 : 0;
}

void ffmpegkit_log_callback_function(void *ptr, int level, const char *format, va_list vargs)
{
    if (runtime_log_callback != NULL) {
        runtime_log_callback(ptr, level, format, vargs);
        return;
    }

    extern void av_log_default_callback(void *avcl, int level, const char *fmt, va_list vl);
    av_log_default_callback(ptr, level, format, vargs);
}