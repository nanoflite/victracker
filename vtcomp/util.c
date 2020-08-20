/*************************************************************************
 *
 * FILE  util.c
 * Copyright (c) 2002, 2003 Daniel Kahlin <daniel@kahlin.net>
 * Written by Daniel Kahlin <daniel@kahlin.net>
 * $Id: util.c,v 1.5 2003/08/26 17:23:51 tlr Exp $
 *
 * DESCRIPTION
 *   Utility functions for vtcomp.
 *
 ******/

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "vtcomp.h"
#include "util.h"

/*************************************************************************
 *
 * NAME  warning()
 *
 * SYNOPSIS
 *   warning (str, ...)
 *   void warning (const char *, ...)
 *
 * DESCRIPTION
 *   output warning message prepended with 'Warning: ' and appended
 *   with '\n'.
 *
 * INPUTS
 *   str              - format string
 *   ...              - vararg parameters
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   none
 *
 ******/
void warning (const char *str, ...)
{
    va_list args;

    fprintf (stderr, "Warning: ");
    va_start (args, str);
    vfprintf (stderr, str, args);
    va_end (args);
    fputc ('\n', stderr);
}


/*************************************************************************
 *
 * NAME  panic()
 *
 * SYNOPSIS
 *   panic (str, ...)
 *   void panic (const char *, ...)
 *
 * DESCRIPTION
 *   output error message prepended with 'PROGRAM: ' and appended
 *   with '\n'.
 *
 * INPUTS
 *   str              - format string
 *   ...              - vararg parameters
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   none
 *
 ******/
void panic (const char *str, ...)
{
    va_list args;

    fprintf (stderr, "%s: ",PROGRAM);
    va_start (args, str);
    vfprintf (stderr, str, args);
    va_end (args);
    fputc ('\n', stderr);
    exit (1);
}

/**************************************************************************
 *
 * Make assembly dc.b statements!
 *
 ******/
void fdumpbytes(FILE *fp, u_int8_t *data, int num, int numperrow, char* dot_byte)
{
    int	i;

    for	(i=0; i < num; i++) {
	if ((i % numperrow)==0)
	    fprintf(fp,"\t%s\t", dot_byte);
	
	if ((i % numperrow)!=numperrow-1 && i!=(num-1))
	    fprintf(fp,"$%02x,",data[i]);
	else
	    fprintf(fp,"$%02x\n",data[i]);
    }
}


/**************************************************************************
 *
 * Make assembly dc.b statements!
 *
 ******/
void fdumplabels(FILE *fp, char *label, int num, int numperrow, char* dot_byte)
{
    int	i;

    for (i=0; i < num; i++) {
	if ((i % numperrow)==0)
	    fprintf(fp,"\t%s\t", dot_byte);
	
	if ((i % numperrow)!=numperrow-1 && i!=(num-1))
	    fprintf(fp,"%s%02x,",label,i);
	else
	    fprintf(fp,"%s%02x\n",label,i);
    }
}

/*************************************************************************
 *
 * NAME  to_petscii()
 *
 * SYNOPSIS
 *   to_petscii (str)
 *   void to_petscii (char *)
 *
 * DESCRIPTION
 *   convert the input to petscii.
 *
 * INPUTS
 *   str              - format string
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   Only does uppercase chars of the input.
 *
 ******/
void to_petscii(char *str)
{
    int i;
    for (i=0; i<strlen(str); i++) {
        str[i]=toupper(str[i]);
    }
}

/*************************************************************************
 *
 * NAME  from_petscii()
 *
 * SYNOPSIS
 *   from_petscii (str)
 *   void from_petscii (char *)
 *
 * DESCRIPTION
 *   convert the input from petscii.
 *
 * INPUTS
 *   str              - format string
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   Only does lowercase of the input.
 *
 ******/
void from_petscii(char *str)
{
    int i;
    for (i=0; i<strlen(str); i++) {
        str[i]=tolower(str[i]);
    }
}

/*************************************************************************
 *
 * NAME  truncstr()
 *
 * SYNOPSIS
 *   truncstr(dst, src, len, pad)
 *   void truncstr(char *, const char *, int, const char)
 *
 * DESCRIPTION
 *   convert the input from petscii.
 *
 * INPUTS
 *   dst              - the destination buffer.
 *   src              - the source string.
 *   len              - the max/min length of the output.
 *   pad              - the pad character to use if the buffer is full.
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   Only does lowercase of the input.
 *
 ******/
void truncstr(char *dst, const char *src, int len, const char pad)
{
    int copylen;

    copylen=(strlen(src)<len)?strlen(src):len;
    memcpy(dst,src,copylen);
    if (copylen<len)
        memset(dst+copylen,pad,len-copylen);
    dst[len]=0;
}

/*************************************************************************
 *
 * NAME  systemf()
 *
 * SYNOPSIS
 *   ret = systemf (fmt, ...)
 *   int systemf (const char *, ...)
 *
 * DESCRIPTION
 *   Do system call using varargs.
 *
 * INPUTS
 *   fmt              - format string
 *   ...              - vararg parameters
 *
 * RESULT
 *   none
 *
 * KNOWN BUGS
 *   none
 *
 ******/
int systemf (const char *fmt, ...)
{
    va_list args;
    char cmdstr[SYSTEMF_LEN];
    int ret;

    va_start (args, fmt);
    vsnprintf (cmdstr, SYSTEMF_LEN, fmt, args);
    va_end (args);

    if (debug_g)
        printf("%s\n",cmdstr);

    ret=system(cmdstr);

    return ret;
}


/*************************************************************************
 *
 * NAME  exists_nonzero()
 *
 * SYNOPSIS
 *   ret = exists_nonzero (filename)
 *   int exists_nonzero (char *)
 *
 * DESCRIPTION
 *   check if the file exists and is non zero in length.
 *
 * INPUTS
 *   filename         - name of the file
 *
 * RESULT
 *   ret              - true if it exists and is non zero.
 *
 * KNOWN BUGS
 *   none
 *
 ******/
int exists_nonzero(char *filename)
{
    int pos;
    FILE *fp;

    fp=fopen(filename,"r");
    if (!fp)
        panic("couldn't open file '%s'",filename);

    if (fseek(fp,0,SEEK_END)==-1)
        panic("couldn't not seek end");

    pos=ftell(fp);
    if (pos==-1)
        panic("couldn't not get file position");

    fclose(fp);

    if (pos==0) {
	return 0;
    }
    return -1;
}

/* eof */
