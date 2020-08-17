/**************************************************************************
 *
 * FILE  tune.h
 * Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
 * Written by Daniel Kahlin <daniel@kahlin.net>
 * $Id: tune.h,v 1.13 2003/08/09 19:12:23 tlr Exp $
 *
 * DESCRIPTION
 *   The vic-tracker module format
 *
 ******/

#define TUNE_ID1         'T'
#define TUNE_ID2         '1'
#define TUNE_PATTLEN	 32
#define TUNE_TABLEN	 256
#define TUNE_MAXPATTERNS 256
#define TUNE_MAXNUMSONGS  14
#define TUNE_MAXNUMSOUNDS 16
#define TUNE_MAXNUMARP    16
#define TUNE_TITLELEN     16
#define TUNE_AUTHORLEN    16
#define TUNE_YEARLEN      4

/* player modes */
#define TUNE_PM_LEGACY	0x00
#define TUNE_PM_PAL	0x01
#define TUNE_PM_PAL2X	0x02
#define TUNE_PM_PAL3X	0x03
#define TUNE_PM_PAL4X	0x04
#define TUNE_PM_NTSC	0x05
#define TUNE_PM_NTSC2X	0x06
#define TUNE_PM_NTSC3X	0x07
#define TUNE_PM_NTSC4X	0x08
#define TUNE_PM_SYNC24	0x09
#define TUNE_PM_SYNC48	0x0a

/* player scales */
#define TUNE_SC_LEGACY	0x00

/* speedflags */
#define TUNE_SPEED_MASK     0x3f
#define TUNE_SPEEDFLAG_MASK 0xc0
#define TUNE_SF_LOOP    0x00
#define TUNE_SF_REPEAT  0x40
#define TUNE_SF_ONESHOT 0x80

/* player commands */
#define TUNE_EF_PORTUP       0x10
#define TUNE_EF_PORTDOWN     0x20
#define TUNE_EF_ARPEGGIO     0x30
#define TUNE_EF_PORTUPSLOW   0x50
#define TUNE_EF_PORTDOWNSLOW 0x60
#define TUNE_EF_SETUSERFLAG  0x70
#define TUNE_EF_SETSOUND     0x80
#define TUNE_EF_CUTNOTE      0xc0
#define TUNE_EF_DELAYNOTE    0xd0

struct SongDef {
    u_int8_t         StartStep;
    u_int8_t         EndStep;
    u_int8_t         RepeatStep;
    u_int8_t         StartSpeed;
};

struct Arpeggio {
    u_int8_t         Data[16];
};
struct ArpeggioConf {
    u_int8_t         Data[2];
};

struct Sound {
    u_int8_t         NoteLen;
    u_int8_t         FreqOffs;
    u_int8_t         FreqGlide;
    u_int8_t         Arpeggio;
    u_int8_t         reserved[4];
};

struct Tab {
    u_int8_t         Data[TUNE_TABLEN];
};

struct Note {
    u_int8_t         Pitch;
    u_int8_t         Param;
};

struct Pattern {
    struct Note      Note[TUNE_PATTLEN];
};

struct Tune {
    u_int8_t	     LoadAddressLow;
    u_int8_t	     LoadAddressHigh;
    u_int8_t	     ID1;
    u_int8_t	     ID2;
    u_int8_t	     Version;
    u_int8_t	     Revision; 
    u_int8_t         PlayMode;
    u_int8_t         Scale;
    u_int8_t         reserved0;
    u_int8_t         SongNum;
    struct SongDef   SongDef[TUNE_MAXNUMSONGS];

    struct Arpeggio  Arpeggio[TUNE_MAXNUMARP];
    struct ArpeggioConf ArpeggioConf[TUNE_MAXNUMARP];
    u_int8_t         reserved1[60];
    char             Title[TUNE_TITLELEN];  /* null terminated _or_ exactly 16 chars */
    char             Author[TUNE_AUTHORLEN]; /* null terminated _or_ exactly 16 chars */
    char             Year[TUNE_YEARLEN];    /* year written as 4 ascii digits */
    struct Sound     Sound[TUNE_MAXNUMSOUNDS];
    u_int8_t         reserved2[128];
    struct Tab       LengthTab;
    struct Tab       Tab[5];

    struct Pattern   Pattern[TUNE_MAXPATTERNS];
};

/**************************************************************************
 *
 * The old T0 format (victracker 1.0 and earlier).
 *
 ******/
#define TUNE_ID1_T0     'T'
#define TUNE_ID2_T0     '0'
#define TUNE_PATTLEN_T0	32
#define TUNE_TABLEN_T0	 256
#define TUNE_MAXPATTERNS_T0 128

struct SongDef_T0 {
    u_int8_t         StartStep;
    u_int8_t         EndStep;
    u_int8_t         StartSpeed;
};

struct Tab_T0 {
    u_int8_t         Data[TUNE_TABLEN_T0];
};

struct Arpeggio_T0 {
    u_int8_t         Data[8];
};

struct Note_T0 {
    u_int8_t         Pitch;
    u_int8_t         Param;
};

struct Pattern_T0 {
    struct Note      Note[TUNE_PATTLEN_T0];
};

struct Tune_T0 {
    u_int8_t         LoadAddressLow;
    u_int8_t         LoadAddressHigh;
    u_int8_t	     ID1;
    u_int8_t	     ID2;
    u_int8_t	     Version;
    u_int8_t	     Revision;
    u_int8_t         reserved0[3];
    u_int8_t         SongNum;
    struct SongDef_T0   SongDef[16];
    u_int8_t         reserved1[8];

    struct Arpeggio_T0  Arpeggio[32];
    struct Tab_T0       Tab[5];

    struct Pattern_T0   Pattern[TUNE_MAXPATTERNS_T0];
};
/* eof */

