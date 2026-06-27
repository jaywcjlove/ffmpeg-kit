/*
 * Copyright (c) 2018-2021 Taner Sener
 *
 * This file is part of FFmpegKit.
 */

#ifndef FFMPEG_KIT_RUNTIME_H
#define FFMPEG_KIT_RUNTIME_H

#include <stdarg.h>

void ffmpegkit_set_session_id(long session_id);
void ffmpegkit_set_log_callback(void (*callback)(void *ptr, int level, const char *format, va_list vargs));
void cancelSession(long sessionId);
int cancelRequested(long sessionId);
void ffmpegkit_log_callback_function(void *ptr, int level, const char *format, va_list vargs);

#endif