/*************************************************************************
 *
 * FILE  util.h
 * Copyright (c) 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
 * Written by Daniel Kahlin <daniel@kahlin.net>
 * $Id: util.h,v 1.4 2003/08/26 15:52:36 tlr Exp $
 *
 * DESCRIPTION
 *   Utility functions for vtcomp.
 *
 ******/

#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>

void warning(const char *str, ...);
void panic(const char *str, ...);

void fdumpbytes(FILE *fp, u_int8_t *data, int num, int numperrow);
void fdumplabels(FILE *fp, char *label, int num, int numperrow);

void to_petscii (char *str);
void from_petscii (char *str);

void truncstr(char *dst, const char *src, int len, const char pad);
#define SYSTEMF_LEN 2048
int systemf (const char *fmt, ...);
int exists_nonzero (char *filename);

/* eof */
