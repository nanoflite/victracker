/**************************************************************************
 *
 * FILE  vtcomp.c
 * Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
 * Written by Daniel Kahlin <daniel@kahlin.net>
 * $Id: vtcomp.c,v 1.46 2004/10/03 16:12:34 tlr Exp $
 *
 * DESCRIPTION
 *   usage: vtcomp <infile> <outfile>
 *
 ******/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "vtcomp.h"
#include "util.h"
#include "tune.h"

#define MODE_PACK     1
#define MODE_CONVERT  2
#define MODE_OPTIMIZE 3

int do_conversion(char *loadname,char *savename);
int do_packing(char *loadname,char *savename);
struct Tune *ConvertT1(struct Tune_T0 *tune);
void ConvertTune(char *filename,struct Tune *tune);
void PackPattern(FILE *fp, struct Pattern *pattern, int pattlen);
void PackPattlist(FILE *fp, struct Tab *tab, u_int8_t startstep, u_int8_t endstep,int repeatstep);
u_int16_t UnpackPattern(FILE *fp, u_int8_t *buffer, u_int8_t *destbuffer);
u_int16_t UnpackPattlist(FILE *fp, u_int8_t *buffer, u_int8_t *destbuffer);
u_int8_t *LoadTune(char *filename);
int SaveTune(char *filename, struct Tune *tune);


#define PATT_CONVERT   (1<<0)
#define PATT_NOCONVERT (1<<1)

/*
 * Conversion table for the editor, so that notes may be entered
 * as two digits, the first meaning octave, and the second meaning note
 * (0-b), 0x3c and 0x3d is the same as 0x40 and 0x41 for making the note value
 * fit into the range 0x00 - 0x3f when needed.
 */
static u_int8_t pitchconvtab[]={
    0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0xff,0xff,0xff,0xff,
    0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0xff,0xff,0xff,0xff,
    0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0xff,0xff,
    0x25,0x26,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
};

static u_int8_t *effect[]={
    "None",
    "Portamento Up",
    "Portamento Down",
    "Arpeggio",
    "N/A",
    "Portamento Up (Slow)",
    "Portamento Down (Slow)",
    "Set User Flag",
    "Set Sound",
    "N/A",
    "N/A",
    "N/A",
    "Cut Note",
    "Delay Note",
    "N/A",
    "N/A"
};

int debug_g=0;
int verbose_g=0;
char *author_g=NULL;
char *title_g=NULL;
char *year_g=NULL;
char *libpath_g=".";

/*************************************************************************
 *
 * NAME  main()
 *
 * SYNOPSIS
 *   ret = main (argc, argv)
 *   void warning (int, char **)
 *
 * DESCRIPTION
 *   The main entry point.
 *
 * INPUTS
 *   argc             - number of arguments
 *   argv             - a list of argument strings 
 *
 * RESULT
 *   ret              - status (0=ok)
 *
 * KNOWN BUGS
 *   none
 *
 ******/
int main(int argc, char *argv[])
{
    int c;
    int ret;
    char *infile,*outfile;
    int operationmode;

    /* defaults */
    operationmode=MODE_PACK;

    /*
     * scan for valid options
     */
    while (EOF!=(c=getopt (argc, argv, "t:a:y:copL:vVhd:"))) {
        switch (c) {
	
	/* a missing parameter */
	case ':':
	/* an illegal option */
	case '?':
	    exit (1);

	/* set debugging */
	case 'd':
	    debug_g=atoi(optarg);
	    break;

	/* set verbose mode */
	case 'v':
	    verbose_g=TRUE;
	    break;

	/* print version */
	case 'V':
	    fprintf (stdout, PROGRAM " " PACKAGE_VER "\n");
	    exit(0);

	/* print help */
	case 'h':
	    fprintf (stdout,
PROGRAM " " PACKAGE_VER "\n"
"Copyright (c) 1994, 2001, 2003 Daniel Kahlin\n"
"Written by Daniel Kahlin <daniel@kahlin.net>\n"
"\n"
"usage: " PROGRAM " [OPTION]... <infile> <outfile>\n"
"\n"
"Valid options:\n"
"    -t <title>      set/override the module title field\n"
"    -a <author>     set/override the module author field\n"
"    -y <year>       set/override the module year field\n"
"    -p              pack <infile> to <outfile>\n"
"    -c              convert <infile> to the current format\n"
"    -o              optimize <infile> and write to <outfile>\n"
"    -L <path>       library path (to find runner.asm and player.asm)\n"
"    -v              be verbose\n"
"    -d <level>      output a lot of (weird) debugging information\n"
"    -v              be verbose\n"
"    -h              displays this help text\n"
"    -V              output program version\n"
"\n"
"Examples:\n"
"    vtcomp -c -t \"rocks!\" -a \"daniel kahlin\" old.vt uptodate.vt\n"
"\n"
"vtcomp does operations on vic-tracker module files.\n");
	    exit (0);
	  
	/* run in conversion mode */
	case 'c':
	    operationmode=MODE_CONVERT;
	    break;

	/* run in optimization mode */
	case 'o':
	    operationmode=MODE_OPTIMIZE;
	    break;

	/* run in pack mode */
	case 'p':
	    operationmode=MODE_PACK;
	    break;

	/* set title */
	case 't':
	    title_g=optarg;
	    break;

	/* set author */
	case 'a':
	    author_g=optarg;
	    break;

	/* set year */
	case 'y':
	    year_g=optarg;
	    break;

	/* set libpath */
	case 'L':
	    libpath_g=optarg;
	    break;

	/* default behavior */
	default:
	    break;
	}
    }

    /*
     * optind now points at the first non option argument
     * we expect two more arguments (infile, outfile)
     */
    if (argc-optind < 2)
        panic ("too few arguments");
    infile=argv[optind];
    outfile=argv[optind+1];

    switch (operationmode) {
    case MODE_PACK:
        ret = do_packing(infile,outfile);
	break;
    case MODE_CONVERT:
        ret = do_conversion(infile,outfile);
	break;
    default:
        panic ("unknown mode");
    }
    exit(ret);
}

/**************************************************************************
 *
 * do_conversion
 *
 ******/
int do_conversion(char *loadname,char *savename)
{
    struct Tune *tune=NULL;
    struct Tune *newtune=NULL;

    tune=(struct Tune *)LoadTune(loadname);
    if (!tune) {
	panic("couldn't load infile!");
    }
    if (tune->ID1==TUNE_ID1_T0 && tune->ID2==TUNE_ID2_T0) {
        if (verbose_g)
	    printf("old (T0) format vic-tracker tune, trying to convert...\n");
	newtune=ConvertT1((struct Tune_T0 *)tune);
	free(tune);
	tune=newtune;
        if (verbose_g)
	    printf("converted from vic-tracker %d.%d format, ok.\n",tune->Version,tune->Revision);
    }
    if (tune->ID1==TUNE_ID1 && tune->ID2==TUNE_ID2) {
        tune->Version=VERSION_MAJOR;
        tune->Revision=VERSION_MINOR;
	if (title_g) {
	    to_petscii(title_g);
	    strncpy(tune->Title,title_g,TUNE_TITLELEN);
	}
	if (author_g) {
	    to_petscii(author_g);
	    strncpy(tune->Author,author_g,TUNE_AUTHORLEN);
	}
	if (year_g) {
	    to_petscii(year_g);
	    strncpy(tune->Year,year_g,TUNE_YEARLEN);
	}

        if (!SaveTune(savename,tune))
	    panic("couldn't write to file '%s'!",savename);
    } else {
	panic("not a vic-tracker tune");
    }

/* all ok exit */
    free(tune);
    return 0;
}

/**************************************************************************
 *
 * do_packing
 *
 ******/
int do_packing(char *loadname,char *savename)
{
    struct Tune *tune=NULL;
    struct Tune *newtune=NULL;

    tune=(struct Tune *)LoadTune(loadname);
    if (!tune) {
        panic("couldn't read from file '%s'!",loadname);
    }
    if (tune->ID1==TUNE_ID1_T0 && tune->ID2==TUNE_ID2_T0) {
	puts("old (T0) format vic-tracker tune, trying to convert.");
	newtune=ConvertT1((struct Tune_T0 *)tune);
	free(tune);
	tune=newtune;
    }
    if (tune->ID1==TUNE_ID1 && tune->ID2==TUNE_ID2) {
	char mainname[256],runnername[256],runnertmpname[256],runnerbinname[256],*dot;
	char titlepad[TUNE_TITLELEN+1];
	char authorpad[TUNE_AUTHORLEN+1];
	char yearpad[TUNE_YEARLEN+1];

	if (title_g) {
	    to_petscii(title_g);
	    strncpy(tune->Title,title_g,TUNE_TITLELEN);
	}
	if (author_g) {
	    to_petscii(author_g);
	    strncpy(tune->Author,author_g,TUNE_AUTHORLEN);
	}
	if (year_g) {
	    to_petscii(year_g);
	    strncpy(tune->Year,year_g,TUNE_YEARLEN);
	}

	/* here the title/author/year info should be fetched */
	truncstr(titlepad,tune->Title,14,' ');
	truncstr(authorpad,tune->Author,14,' ');
	truncstr(yearpad,tune->Year,4,' ');

	strncpy(mainname,savename,256);
	dot=strrchr(mainname,'.');
	if (dot) *dot=0;
	snprintf(runnertmpname,256,"%s_runner.tmp",mainname);
	snprintf(runnername,256,"%s_runner.asm",mainname);
	snprintf(runnerbinname,256,"%s_runner.prg",mainname);

	if (verbose_g)
	    printf("file: '%s' \n",loadname);

	ConvertTune(savename,tune);

	if (verbose_g)
	    printf("Created file '%s'.\n",savename);
	systemf("cat %s/%s | sed 's/@FILE@/\"%s\\.asm\"/' | sed 's/@VERSION@/\"%s\"/' | sed 's/@NUMSONGS@/%d/' | sed 's/@TITLE@/\"%s\"/' | sed 's/@AUTHOR@/\"%s\"/' > %s",libpath_g,"runner.asm",mainname,VERSION,tune->SongNum,titlepad,authorpad,runnertmpname);

	{
	    int rn_vtcomp=1;
	    int rn_unexp=1;
	    int rn_debug=0;
	    int rn_speed_1x=0,rn_speed_2x=0,rn_speed_3x=0,rn_speed_4x=0;

	    /*
	     * determine which interrupt speed we shall have
	     */
	    switch (tune->PlayMode) {
	    case TUNE_PM_LEGACY:
	    case TUNE_PM_PAL:
	    case TUNE_PM_NTSC:
	        rn_speed_1x=1;
		break;
	    case TUNE_PM_PAL2X:
	    case TUNE_PM_NTSC2X:
	        rn_speed_2x=1;
		break;
	    case TUNE_PM_PAL3X:
	    case TUNE_PM_NTSC3X:
	        rn_speed_3x=1;
		break;
	    case TUNE_PM_PAL4X:
	    case TUNE_PM_NTSC4X:
	        rn_speed_4x=1;
		break;
	    default:
	        /* unknown playmode always results in single speed */
	        rn_speed_1x=1;
		break;
	    }

	    systemf("../utils/strip.pl %s"
		    "-%cRN_VTCOMP "
		    "-%cRN_UNEXP "
		    "-%cRN_DEBUG "
		    "-%cRN_SPEED_1X "
		    "-%cRN_SPEED_2X "
		    "-%cRN_SPEED_3X "
		    "-%cRN_SPEED_4X "
		    "-o %s %s",
		    (debug_g)?"-v ":"",
		    (rn_vtcomp)?'D':'U',
		    (rn_unexp)?'D':'U',
		    (rn_debug)?'D':'U',
		    (rn_speed_1x)?'D':'U',
		    (rn_speed_2x)?'D':'U',
		    (rn_speed_3x)?'D':'U',
		    (rn_speed_4x)?'D':'U',
		    runnername,
		    runnertmpname
	    );
	    unlink(runnertmpname);
	}
	if (verbose_g)
	    printf("Created file '%s'.\n",runnername);
	systemf("dasm %s -o%s %s",runnername,runnerbinname,(verbose_g)?"":"> /dev/null");
	if (!exists_nonzero(runnerbinname)) {
	    unlink(runnerbinname);
	    panic("dasm created an empty output file");
	}
	if (verbose_g)
	    printf("Created file '%s'.\n",runnerbinname);
    } else {
	panic("not a vic-tracker tune");
    }

/* all ok exit */
    free(tune);
    return 0;
}


/**************************************************************************
 *
 * ConvertT1
 *
 ******/
struct Tune *ConvertT1(struct Tune_T0 *tune)
{
    int i,j;
    int Version;
    int Revision;
    struct Tune *newtune;

    newtune=calloc(1,sizeof(struct Tune));
    if (!newtune)
        panic("couldn't allocate memory");

/* this will detect a victracker tune created by VIC-TRACKER 0.1 or 0.3 */
    if (tune->SongNum==0 && tune->reserved0[0]!=0) {
	/* vt-0.1 had a load address of 0x2000, vt-0.3 had 0x2800. */
	if (tune->LoadAddressLow==0x00 && tune->LoadAddressHigh==0x20) {
	    Version=0;
	    Revision=1;
	} else {
	    Version=0;
	    Revision=3;
	}
/* this will detect a victracker tune created by VIC-TRACKER 0.4 */
    } else if (tune->SongNum==0 && tune->Version==1 && tune->Revision==0 &&
	       tune->LoadAddressLow==0x00 && tune->LoadAddressHigh==0x28) {
	Version=0;
	Revision=4;
/* this will detect a victracker tune created by VIC-TRACKER 0.5 or later */
    } else {
        Version=tune->Version;
        Revision=tune->Revision;
    }

/* now we know the version... convert! */
    if (Version==0 && Revision<=3) {
	tune->SongDef[0].StartStep=tune->Version;
	tune->SongDef[0].EndStep=tune->Revision;
	tune->SongDef[0].StartSpeed=tune->reserved0[0];
	tune->SongNum=1;
    } else if (Version==0 && Revision==4) {
	tune->SongNum=1;
    }
/* here we should probably do a sanity check to see if the converted
   module is ok */

/* setup control parameters */
    newtune->LoadAddressLow=0x00;
    newtune->LoadAddressHigh=0x33;
    newtune->ID1=TUNE_ID1;
    newtune->ID2=TUNE_ID2;
    newtune->Version=Version;
    newtune->Revision=Revision;
    newtune->PlayMode=TUNE_PM_LEGACY;
    newtune->Scale=TUNE_SC_LEGACY;

/* setup songs. */
    newtune->SongNum=tune->SongNum;
    for (i=0; i<tune->SongNum; i++) {
        newtune->SongDef[i].StartStep=tune->SongDef[i].StartStep;
        newtune->SongDef[i].EndStep=tune->SongDef[i].EndStep;
        newtune->SongDef[i].RepeatStep=tune->SongDef[i].StartStep;
        newtune->SongDef[i].StartSpeed=tune->SongDef[i].StartSpeed | TUNE_SF_LOOP;
    }

/* set up default arpeggio conf (mode f, speed 0, repeatstep 0, endstep 7) */
    for (i=0; i<TUNE_MAXNUMARP; i++) {
        newtune->ArpeggioConf[i].Data[0]=0xf0;
        newtune->ArpeggioConf[i].Data[1]=0x07;
    }

/* set up default sounds (length 0, FreqOffs $fc) */
    for (i=0; i<TUNE_MAXNUMSOUNDS; i++) {
        newtune->Sound[i].FreqOffs=0xfc;
    }

/* transfer the arpeggio data */
    for (i=15; i>=0; i--) {
        for (j=0; j<8; j++) {
            newtune->Arpeggio[i].Data[j]=tune->Arpeggio[i].Data[j];
	}
    }

/* transfer the patternlists and set ut default length */
    for (i=0; i<TUNE_TABLEN_T0; i++) {
         newtune->LengthTab.Data[i]=0x1f;
	 for (j=0; j<5; j++) {
	     newtune->Tab[j].Data[i]=tune->Tab[j].Data[i];
	 }
    }

/* transfer the patterns */
    for (i=0; i<TUNE_MAXPATTERNS_T0; i++) {
        for (j=0; j<TUNE_PATTLEN_T0; j++) {
	    newtune->Pattern[i].Note[j].Pitch=tune->Pattern[i].Note[j].Pitch;
	    newtune->Pattern[i].Note[j].Param=tune->Pattern[i].Note[j].Param;
	}
    }


    return newtune;
}

/**************************************************************************
 *
 * ConvertTune
 *
 ******/
void ConvertTune(char *filename,struct Tune *tune)
{
    FILE *fp;
    int i,j,k,l;
    u_int8_t pattnum=0;
    u_int8_t arpnum=0;
    u_int8_t soundnum=0;
    u_int8_t minspeed,maxspeed;
    u_int8_t minvolume,maxvolume;
    int uses_spdchange=0;
    int uses_volparams=0;
    u_int8_t pitch=0;
    u_int8_t param=0;
    u_int8_t paramtab[256];
    u_int8_t paramsubst[256];
    u_int8_t  patterntab[256];
    u_int8_t  patternlentab[256];
    u_int32_t patternlenmasktab[256];
    u_int8_t  patternsubst[256];
    u_int8_t  newpatterntab[256];
    u_int8_t  newpatternlentab[256];
    u_int32_t newpatternlenmasktab[256];
    u_int8_t  newpatternsubst[256];
    u_int8_t effecttab[16];
    u_int8_t arptab[16];
    u_int8_t arpsubst[16];
    u_int8_t arpmodetab[16];
    u_int8_t soundtab[16];
    u_int8_t soundsubst[16];
    u_int8_t soundarptab[16];
    int uses_soundarp=0;
    int uses_soundglide=0;
    int uses_soundfreqoffs=0;
    int uses_volvoice=0;
    struct Tune *newtune;

    newtune=calloc(1,sizeof(struct Tune));
    if (!newtune)
        panic("couldn't allocate memory");

    if (verbose_g) {
        printf("- vic-tracker version: %d.%d\n",tune->Version,tune->Revision);
	printf("- number of songs: %d\n",tune->SongNum);
    }

    for (i=0; i<tune->SongNum; i++) {
	if (verbose_g) {
	    printf("    song %d: step %02x-%02x, speed %02x, ",
		   i,
		   tune->SongDef[i].StartStep,
		   tune->SongDef[i].EndStep,
		   tune->SongDef[i].StartSpeed & TUNE_SPEED_MASK
	    );
	}

	switch (tune->SongDef[i].StartSpeed & TUNE_SPEEDFLAG_MASK) {
	case TUNE_SF_LOOP:
	    if (verbose_g)
	        printf("loop\n");
	    break;
	case TUNE_SF_REPEAT:
	    if (verbose_g)
	        printf("repeat %02x\n",tune->SongDef[i].RepeatStep);
	    break;
	case TUNE_SF_ONESHOT:
	    if (verbose_g)
	        printf("one-shot\n");
	    warning("one shot is not yet supported in the player");
	    break;
	default:
	    panic("invalid speedflag");
	}
    }

/* clear tables */
    for (i=0; i < 256; i++) {
	paramtab[i]=0;
	paramsubst[i]=0;
	patterntab[i]=0;
	patternlentab[i]=0;
	patternlenmasktab[i]=0;
	patternsubst[i]=0;
	newpatterntab[i]=0;
	newpatternlentab[i]=0;
	newpatternlenmasktab[i]=0;
	newpatternsubst[i]=0;
    }
    for (i=0; i < 16; i++) {
	effecttab[i]=0;
	arpsubst[i]=0;
	arptab[i]=0;
	arpmodetab[i]=0;
	soundsubst[i]=0;
	soundtab[i]=0;
	soundarptab[i]=0;
    }



/*
 * Determine the minimum and maximum speed used.
 * Determine the minimum and maximum volume used.
 *
 * This routine will determine;
 * - if params are used in the volume voice
 * - if speed is changed in the volume voice
 * - the minimum speed count used
 */
    minspeed=255;
    maxspeed=0;
    minvolume=255;
    maxvolume=0;
    for (k=0; k<tune->SongNum; k++) {
        int spd;
        int initialspd;
        int vol;
	initialspd=tune->SongDef[k].StartSpeed & TUNE_SPEED_MASK;
        if (initialspd < minspeed)
	    minspeed=initialspd;
	if (initialspd > maxspeed)
	    maxspeed=initialspd;
        for (i=tune->SongDef[k].StartStep; i<=tune->SongDef[k].EndStep; i++) {
	    for (j=0; j<=tune->LengthTab.Data[i]; j++) {
	        u_int8_t pitch,param;
		pitch=tune->Pattern[tune->Tab[4].Data[i]].Note[j].Pitch;
		param=tune->Pattern[tune->Tab[4].Data[i]].Note[j].Param;
		/* check speed */
	        spd = pitch >> 4; 
	        if (spd!=0 && spd < minspeed) 
		    minspeed=spd;
	        if (spd!=0 && spd > maxspeed) 
		    maxspeed=spd;
	        if (spd!=0 && spd != initialspd) 
		    uses_spdchange=1;
		/* check volume */
		vol = pitch & 0x0f;
	        if (vol < minvolume) 
		    minvolume=vol;
	        if (vol > maxvolume) 
		    maxvolume=vol;
		/* check param */
		if (param)
		    uses_volparams=1;
	    }	
	}
    }

    if (uses_volparams || uses_spdchange || minvolume!=maxvolume) {
        uses_volvoice=1;
    } else {
        /* erase the patterns in the volume voice so they get deleted 
	   during optimization, this assumes that pattern 00 is empty */
        for (k=0; k<tune->SongNum; k++) {
	    for (i=tune->SongDef[k].StartStep; i<=tune->SongDef[k].EndStep; i++) {
	        tune->Tab[4].Data[i]=0x00;
	    }	
	}
    }

    if (verbose_g) {
        printf("minspeed %02x\n",minspeed);
        printf("maxspeed %02x\n",maxspeed);
        printf("minvolume %02x\n",minvolume);
        printf("maxvolume %02x\n",maxvolume);
        printf("uses volparams %d\n",uses_volparams);
        printf("uses spdchange %d\n",uses_spdchange);
    }

/*
 * Make a map of all patterns used! (voice 1-5)
 * for each pattern make a mask of which voices it appears in,
 * and mask of which lengths it appears as.
 */
    for (k=0; k<tune->SongNum; k++) {
        for (i=tune->SongDef[k].StartStep; i<=tune->SongDef[k].EndStep; i++) {
            for (j=0; j < 5; j++) {
	        if (j<3) {
		    patterntab[tune->Tab[j].Data[i]]|=PATT_CONVERT;
	        } else {
		    patterntab[tune->Tab[j].Data[i]]|=PATT_NOCONVERT;
	        }
		patternlenmasktab[tune->Tab[j].Data[i]]|=1<<tune->LengthTab.Data[i];
	    }	
	}
    }

/* calculate the maximum length of each pattern */
    for (i=0; i < TUNE_MAXPATTERNS; i++) {
        if (patterntab[i]) {
	    int pattlen;
	    for (pattlen=31; pattlen>=0; pattlen--) {
	        if (patternlenmasktab[i]&(1<<pattlen))
		    break;
	    }
	    patternlentab[i]=pattlen;
	}
    }

/* Substitute patterns. */
    j=0;
    for (i=0; i < TUNE_MAXPATTERNS; i++) {
        for (k=31; k>=0; k--) {
	    if (patternlenmasktab[i]&(1<<k)) {
	        for (l=0; l<=1; l++) {
		    if (patterntab[i]&(1<<l)) {
		        patternsubst[i]=j;
			if (debug_g>=1) printf("patt %d, newpatt %d, len %02x\n",i,j,sizeof(struct Note)*(k+1));
			memcpy(&(newtune->Pattern[j]),&(tune->Pattern[i]),sizeof(struct Note)*(k+1));
			newpatterntab[j]|=patterntab[i]&(1<<l);
			newpatternsubst[j]=i;
			newpatternlentab[j]=k;
			newpatternlenmasktab[j]|=1<<k;
			j++;
		    }
		}
	    }
	}
    }
    pattnum=j;	


/*
 * substitute notes in patterns used in voice 1-3
 *
 */
    for (i=0; i < TUNE_MAXPATTERNS; i++) {
	if (newpatterntab[i]&PATT_CONVERT) {
	    for (k=0; k <=newpatternlentab[i]; k++) {
		pitch=newtune->Pattern[i].Note[k].Pitch;
		newtune->Pattern[i].Note[k].Pitch=(pitchconvtab[pitch&0x7f])|(pitch&0x80);
	    }			
	}
    }


/* Do substitution in pattlist */
    for (k=0; k<tune->SongNum; k++) {
        for (i=tune->SongDef[k].StartStep; i<=tune->SongDef[k].EndStep; i++) {
	    for (j=0; j < 5; j++) {
		int this_patt=tune->Tab[j].Data[i];
		int this_len=tune->LengthTab.Data[i];
		int found_patt=-1;
		for (l=0; l<pattnum; l++) {
		    if (this_patt==newpatternsubst[l] && newpatternlentab[l]==this_len) {
			if ((j<3) && (newpatterntab[l]&PATT_CONVERT)) {
			    found_patt=l;
			    break;
			}
			if ((j>=3) && (newpatterntab[l]&PATT_NOCONVERT)) {
			    found_patt=l;
			    break;
			}
		    }
		}
		if (found_patt==-1) {
		    panic("couldn't find a suitable pattern!");
		}
	        newtune->Tab[j].Data[i]=found_patt;
	    }
	}
    }

/* Make a map of params and what effects are used (all patterns found) */
    for (i=0; i < TUNE_MAXPATTERNS; i++) {
        if (patterntab[i]) {
	    for (k=0; k <= patternlentab[i]; k++) {
		paramtab[tune->Pattern[i].Note[k].Param]=1;
		effecttab[(tune->Pattern[i].Note[k].Param)>>4]=1;
	    }
	}	
    }

/* Print which effects are used. */
    if (verbose_g) {
        printf("- used effects:\n");
	for (i=0; i < 16; i++) {
	    if (effecttab[i])
	        printf("    %01x %s\n",i,effect[i]);
	}
    }

/*
 * Determine which sounds are used and remap them.
 */
    j=0;
    if (verbose_g)
        printf("- used sounds:\n    ");
    for (i=0; i < 16; i++) {
        /* check if the sound is used.  (sound #0 is always the default) */
	if (paramtab[i+0x80] || i==0) {
	    soundtab[i]=1;
	    soundsubst[i]=j;
	    memcpy(&(newtune->Sound[j]),&(tune->Sound[i]),sizeof(struct Sound));

	    if (verbose_g) {
	        if (j!=0)
		    printf(", ");
		printf("%01x",i);
	    }
	    j++;
	}
    }
    soundnum=j;
    if (verbose_g)
        printf("\n");
/*
 * soundsubst[] contains the mapping between old sound numbers and new.
 * now the sounds are in the correct order in newtune.
 * and the number of sounds are in soundnum.
 */

/* check the used sounds for referred arpeggios or glide usage */
    for (i=0; i < 16; i++) {
	if (soundtab[i]) {
	    if (tune->Sound[i].FreqOffs!=0x00) {
		uses_soundfreqoffs=1;
	    }
	    if (tune->Sound[i].FreqGlide!=0x00) {
	        uses_soundglide=1;
	    }
	    if (tune->Sound[i].Arpeggio&0x80) {
	        uses_soundarp=1;
		soundarptab[tune->Sound[i].Arpeggio&0x7f]=1;
	    }
	}
    }


/*
 * Determine which arpeggios are used and remap them.
 */
    j=0;
    if (verbose_g)
        printf("- used arpeggios:\n    ");
    for (i=0; i < 16; i++) {
	if (paramtab[i+0x30] || soundarptab[i]) {
	    arptab[i]=1;
	    arpsubst[i]=j;
	    memcpy(&(newtune->Arpeggio[j]),&(tune->Arpeggio[i]),sizeof(struct Arpeggio));
	    memcpy(&(newtune->ArpeggioConf[j]),&(tune->ArpeggioConf[i]),sizeof(struct ArpeggioConf));
	    if (verbose_g) {
	        if (j!=0)
		    printf(", ");
		printf("%01x",i);
	    }
	    j++;
	}
    }
    arpnum=j;
    if (verbose_g) 
        printf("\n");

/*
 * arpsubst[] contains the mapping between old sound numbers and new.
 * now the arpeggios are in the correct order in newtune.
 * and the number of arpeggios are in arpnum.
 */

/*
 * Make a map of used arpeggio modes, and 
 * convert absolute notes in mode 0 arpeggios.
 */
    for (i=0; i < arpnum; i++) {
        u_int8_t mode;
	mode=newtune->ArpeggioConf[i].Data[0]>>4;
	arpmodetab[mode]=1;
	if (mode==0x00) {
	    for (j=0; j < 16; j++) {
	        u_int8_t data;
		data=newtune->Arpeggio[i].Data[j];
		if (data & 0x40) {
		    data=(data&0xc0)|pitchconvtab[data&0x3f];
		}
		newtune->Arpeggio[i].Data[j]=data;
	    }
	}
    }

/*
 * substitute effect params referring to renumbered arpeggios and
 * sounds.
 */
    for (i=0; i < pattnum; i++) {
        for (k=0; k < TUNE_PATTLEN; k++) {
	    param=newtune->Pattern[i].Note[k].Param;
	    switch (param >> 4) {
	    case 3:
	        param=(param&0xf0)+arpsubst[param&0x0f];
		break;
	    case 8:
	        param=(param&0xf0)+soundsubst[param&0x0f];
		break;
	    default:
	        break;
	    }
	    newtune->Pattern[i].Note[k].Param=param;
	}			
    }


/*
 * substitute sound references to renumbered arpeggios.
 */
    for (i=0; i < soundnum; i++) {
        if (newtune->Sound[i].Arpeggio&0x80) {
	    newtune->Sound[i].Arpeggio=arpsubst[newtune->Sound[i].Arpeggio&0x7f]|0x80;
	}
    }

/*
 * now we have an optimized module in newtune.
 */


/*
 * Generate the output!
 *
 */
    {
        int pl_vtcomp=1;
        int pl_userflag=0;
        int pl_delay=0;
	int pl_sounds=1;
	int pl_songs=0;
	int pl_arpeggios=0,pl_arpsound=0,pl_arpeffect=0;
	int pl_portamento=0,pl_portsound=0,pl_porteffect=0;
	int pl_arpmode00=0,pl_arpmode10=0,pl_arpmodef0=0;
	int pl_exactpreload=1;
	int pl_no_optimize=1,pl_optimize_five=0,pl_optimize_three=0,pl_optimize_two=0,pl_optimize_one=0;
	int pl_volvoice=0;
	
	/*
	 * determine if we need to support different songs.
	 */
	if (tune->SongNum>1)
	    pl_songs=1;

	/*
	 * select various arpeggio modes.
	 */
	if (arpmodetab[0x0])
	    pl_arpmode00=1;
	if (arpmodetab[0x1])
	    pl_arpmode10=1;
	if (arpmodetab[0xf])
	    pl_arpmodef0=1;

	/*
	 * select various effects.
	 */
	if (effecttab[0xd])
	    pl_delay=1;
	if (effecttab[0x7])
	    pl_userflag=1;
	if (effecttab[0x3]) {
	    pl_arpeffect=1;
	    pl_arpeggios=1;
	}
	if (uses_soundarp) {
	    pl_arpsound=1;
	    pl_arpeggios=1;
	}
	if (effecttab[0x1] || effecttab[0x2] || 
	    effecttab[0x5] || effecttab[0x6]) {
	    pl_porteffect=1;
	    pl_portamento=1;
	}
	if (uses_soundglide) {
	    pl_portsound=1;
	    pl_portamento=1;
	}
	if (uses_soundfreqoffs)
	    pl_portamento=1;

	/*
	 * select optimization mode depending on the minimum speed value
         * of the songs.
         */
	if (minspeed >= 1 && minspeed < 2 ) {
	    pl_optimize_one=1;
	    pl_no_optimize=0;
	}
	if (minspeed >= 2 && minspeed < 3 ) {
	    pl_optimize_two=1;
	    pl_no_optimize=0;
	}
	if (minspeed >= 3 && minspeed < 5 ) {
	    pl_optimize_three=1;
	    pl_no_optimize=0;
	}
	if (minspeed >= 5) {
	    pl_optimize_five=1;
	    pl_no_optimize=0;
	}
	/*
	 * determine if we need to support the volume voice at all.
	 */
	if (uses_volvoice)
	    pl_volvoice=1;

	systemf("../utils/strip.pl %s"
		 "-%cPL_VTCOMP "
		 "-%cPL_SUPPORT_USERFLAG "
		 "-%cPL_SUPPORT_ARPEGGIOS "
		 "-%cPL_SUPPORT_ARPSOUND "
		 "-%cPL_SUPPORT_ARPEFFECT "
		 "-%cPL_SUPPORT_PORTAMENTO "
		 "-%cPL_SUPPORT_PORTSOUND "
		 "-%cPL_SUPPORT_PORTEFFECT "
		 "-%cPL_SUPPORT_DELAY "
		 "-%cPL_SUPPORT_SOUNDS "
		 "-%cPL_SUPPORT_SONGS "
		 "-%cPL_SUPPORT_ARPMODE00 "
		 "-%cPL_SUPPORT_ARPMODE10 "
		 "-%cPL_SUPPORT_ARPMODEF0 "
		 "-%cPL_SUPPORT_EXACTPRELOAD "
		 "-%cPL_NO_OPTIMIZE "
		 "-%cPL_OPTIMIZE_FIVE "
		 "-%cPL_OPTIMIZE_THREE "
		 "-%cPL_OPTIMIZE_TWO "
		 "-%cPL_OPTIMIZE_ONE "
		 "-%cPL_SUPPORT_VOLVOICE "
		 "-o %s %s/%s",
	    (debug_g)?"-v ":"",
            (pl_vtcomp)?'D':'U',
            (pl_userflag)?'D':'U',
            (pl_arpeggios)?'D':'U',
            (pl_arpsound)?'D':'U',
            (pl_arpeffect)?'D':'U',
            (pl_portamento)?'D':'U',
            (pl_portsound)?'D':'U',
            (pl_porteffect)?'D':'U',
            (pl_delay)?'D':'U',
	    (pl_sounds)?'D':'U',
	    (pl_songs)?'D':'U',
	    (pl_arpmode00)?'D':'U',
	    (pl_arpmode10)?'D':'U',
	    (pl_arpmodef0)?'D':'U',
	    (pl_exactpreload)?'D':'U',
	    (pl_no_optimize)?'D':'U',
	    (pl_optimize_five)?'D':'U',
	    (pl_optimize_three)?'D':'U',
	    (pl_optimize_two)?'D':'U',
	    (pl_optimize_one)?'D':'U',
	    (pl_volvoice)?'D':'U',
	    filename,
	    libpath_g,
	    "player.asm"
	);
    }
    if (!(fp=fopen(filename,"a")))
	panic("couldn't open file '%s' for writing",filename);


    fprintf(fp,
	    "\n"
	    ";**************************************************************************\n"
	    ";*\n"
	    ";* vic-tracker module\n"
	    ";*\n"
	    ";* This file was generated by:\n"
	    ";*   vtcomp (" PACKAGE ") " VERSION " by Daniel Kahlin <daniel@kahlin.net>\n"
	    ";*\n");

/* Print which effects are used. */
    fprintf(fp,";* used effects:\n");
    for (i=0; i < 16; i++) {
	if (effecttab[i])
	    fprintf(fp,";*  - %01x %s\n",i,effect[i]);
    }

    fprintf(fp,";* number of songs ...... %d\n",tune->SongNum);
    fprintf(fp,";* number of patterns ... %d\n",pattnum);
    fprintf(fp,";* number of sounds ..... %d\n",soundnum);
    fprintf(fp,";* number of arpeggios .. %d\n",arpnum);
    fprintf(fp,";* min speed count ...... %d\n",minspeed);

/* end of the header */
    fprintf(fp,
	    ";*\n"
	    ";******\n");

/* generate general configuration data */
    fprintf(fp,"pl_SongSpeed:\n");
    for (i=0; i<tune->SongNum; i++) {
        fprintf(fp,"\tdc.b\t$%02x\n",tune->SongDef[i].StartSpeed & TUNE_SPEED_MASK);
    }
    if (tune->SongNum>1) {
        fprintf(fp,"pl_SongLow:\n");
	for (i=0; i<tune->SongNum; i++) {
 	    if (uses_volvoice) {
	        fprintf(fp,"\tdc.b\t<pl_Tab1_%d,<pl_Tab2_%d,<pl_Tab3_%d,<pl_Tab4_%d,<pl_Tab5_%d\n",i,i,i,i,i);
	    } else {
	        fprintf(fp,"\tdc.b\t<pl_Tab1_%d,<pl_Tab2_%d,<pl_Tab3_%d,<pl_Tab4_%d\n",i,i,i,i);
	    }
	}
	fprintf(fp,"pl_SongHigh:\n");
	for (i=0; i<tune->SongNum; i++) {
 	    if (uses_volvoice) {
	        fprintf(fp,"\tdc.b\t>pl_Tab1_%d,>pl_Tab2_%d,>pl_Tab3_%d,>pl_Tab4_%d,>pl_Tab5_%d\n",i,i,i,i,i);
	    } else {
	        fprintf(fp,"\tdc.b\t>pl_Tab1_%d,>pl_Tab2_%d,>pl_Tab3_%d,>pl_Tab4_%d\n",i,i,i,i);
	    }
	}
    }

/* Generate Sounds (packed player uses only 4 bytes per sound) */
    if (soundnum) {
        fprintf(fp,"pl_Sounds:\n");
	for (i=0; i < soundnum; i++) {
	    fdumpbytes(fp,
		       (u_int8_t *)&newtune->Sound[i],
		       4,
		       16
		       );
	}
    }

/* Generate Arpeggios and ArpeggioConf */
    /*if (arpnum)*/ {
        fprintf(fp,"pl_ArpeggioIndex:\n");
	for (i=0; i < arpnum; i++) {
	    fprintf(fp,"\tdc.b\tpl_Arp%02x-pl_Arpeggios\n",i);
	}

        fprintf(fp,"pl_Arpeggios:\n");
	for (i=0; i < arpnum; i++) {
	    fprintf(fp,"pl_Arp%02x:\n",i);
	    fdumpbytes(fp,
		       (u_int8_t *)&newtune->Arpeggio[i],
		       (newtune->ArpeggioConf[i].Data[1]&0x0f)+1,
		       16
		       );
	}

	fprintf(fp,"pl_ArpeggioConf:\n");
	for (i=0; i < arpnum; i++) {
	    fdumpbytes(fp,(u_int8_t *)&newtune->ArpeggioConf[i],2,2);
	}
    }

/* Generate pattlist */
    for (i=0; i<tune->SongNum; i++) {
        int repeatstep;
	switch (tune->SongDef[i].StartSpeed & TUNE_SPEEDFLAG_MASK) {
	case TUNE_SF_LOOP:
	    repeatstep=tune->SongDef[i].StartStep;
	    break;
	case TUNE_SF_REPEAT:
	    repeatstep=tune->SongDef[i].RepeatStep;
	    break;
	case TUNE_SF_ONESHOT:
	    repeatstep=0;
	    break;
	default:
	    panic("invalid speedflag");
	}
        for (j=0; j < ((uses_volvoice)?5:4); j++) {
	    fprintf(fp,"pl_Tab%d_%d:\n",j+1,i);
	    if (verbose_g)
	        printf("packing pattlist %d (song %d)...",j+1,i);
	    PackPattlist(fp,&newtune->Tab[j],tune->SongDef[i].StartStep,tune->SongDef[i].EndStep,repeatstep);
	}
    }

    fprintf(fp,"pl_PatternsLow:\n");
    fdumplabels(fp,"<pl_Patt",pattnum,5);
    fprintf(fp,"pl_PatternsHigh:\n");
    fdumplabels(fp,">pl_Patt",pattnum,5);

/* Generate patterns */
    for (i=0; i < pattnum; i++) {
        fprintf(fp,"pl_Patt%02x:\n",i);
	if (verbose_g)
	    printf("packing pattern %02x...",i);
	PackPattern(fp,&(newtune->Pattern[i]),newpatternlentab[i]+1);
    }


/* Terminate */
    fprintf(fp,"; eof\n");
    fclose(fp);
}


/**************************************************************************
 *
 * PackPattlist and output to file
 *
 ******/
int _PackPattlist(struct Tab *tab, u_int8_t startstep, u_int8_t endstep, u_int8_t *pattlistbuffer, int index)
{
    u_int8_t datacache[256];
    int thisstep;
    u_int8_t state;
    u_int8_t count;
    u_int8_t run;
    int j;
    thisstep=startstep;
    count=0;
    state=16;
    run=TRUE;
    while (run) {
        if (thisstep<=endstep) {
	    datacache[count]=tab->Data[thisstep];
	    switch(state) {
	    case 16:
	        state=0;
		break;
	    case 0:
	        if (datacache[count]==datacache[count-1])
		    {state=8; break;}
		if (datacache[count]!=datacache[count-1])
		    {state=9; break;}
		state|=32;
		break;
	    case 8:
	        if (datacache[count]==datacache[count-1])
		    {state=8; break;}
		state|=32;
		break;
	    case 9:
	        if (datacache[count]!=datacache[count-1])
		    {state=9; break;}
		count--;
		thisstep--;
		state|=32;
		break;
	    default:
	        puts("error");
		break;
	    }				
	} else {
	    state|=32;
	    run=FALSE;
	}
	
	if (state&32) {
	    switch (state&0x03) {
	    case 0:
	        pattlistbuffer[index++]=0x80+(count-1);
		pattlistbuffer[index++]=datacache[0];
		break;
	    case 1:
	        for (j=0; j<count; j++)
		    pattlistbuffer[index++]=datacache[j];
		break;
	    default:
	        puts("unknown state");
		break;
	    }
	    count=0;
	    state=16;
	} else {
	    count++;
	    thisstep++;
	}
    }
    return index;
}

void PackPattlist(FILE *fp, struct Tab *tab, u_int8_t startstep, u_int8_t endstep, int repeatstep)
{
    u_int8_t pattlistbuffer[256];
    u_int8_t pattlistbuffer2[256];
    u_int8_t index,repeatindex;
    u_int16_t len;

    if (repeatstep<startstep || repeatstep>endstep)
        panic("repeatstep must be within the range of startstep and endstep");

    index=0;
    if (repeatstep==startstep) {
        repeatindex=0;
	index=_PackPattlist(tab,startstep,endstep,pattlistbuffer,index);
    } else {
	index=_PackPattlist(tab,startstep,repeatstep-1,pattlistbuffer,index);
	repeatindex=index;
	index=_PackPattlist(tab,repeatstep,endstep,pattlistbuffer,index);
    }
    /* set end marker depending on the repeat mode */
    if (repeatstep!=-1) {
        if (repeatindex > 0x3e)
	    panic("repeatindex bigger than 0x3e is not supported");
	pattlistbuffer[index++]=0xc0 | repeatindex;
    } else {
        pattlistbuffer[index++]=0xff; /* END OF SONG marker */
    }
    fdumpbytes(fp,pattlistbuffer,index,16);

    len=UnpackPattlist(fp,pattlistbuffer,pattlistbuffer2);

    if ((!memcmp(&(tab->Data[startstep]),pattlistbuffer2,(endstep-startstep)+1)) && len==(endstep-startstep)+1) {
	if (verbose_g)
	    printf("unpacks ok. ");
    } else {
	if (verbose_g)
	    printf("couldn't unpack! ");
	panic("couldn't unpack patternlist");
    }
    if (verbose_g)
        printf("(size: $%02x)\n",index);

}

/**************************************************************************
 *
 * Unpackpattlist and output to file
 *
 ******/
u_int16_t UnpackPattlist(FILE *fp, u_int8_t *buffer, u_int8_t *destbuffer)
{
    u_int8_t data;
    int i=0,j=0;
    u_int8_t index=0;
    u_int8_t run=TRUE;

/* clear tables */
    for (i=0; i < 256; i++) {
	destbuffer[i]=0;
    }

    i=0;
    while(run) {
	data=buffer[i++];

	switch (data & 0xc0) {
	case 0x00:
	case 0x40:
	    destbuffer[index++]=data&0x7f;
	    break;
	case 0x80:
	    for (j=0; j<=(data&0x3f); j++)
		destbuffer[index++]=buffer[i];
	    i++;
	    break;
	case 0xc0:
	    run=FALSE;
	    break;
	default:
	    break;
	}

    }
	

    return(index);
}

/**************************************************************************
 *
 * Packpattern and output to file
 *
 ******/
void PackPattern(FILE *fp, struct Pattern *pattern, int pattlen)
{
    u_int8_t patternbuffer[256];
    u_int8_t patternbuffer2[256];
    u_int8_t pitchcache[256],paramcache[256];
    u_int8_t state=16;
    u_int8_t count=0;
    u_int8_t index=0;
    int	i,j;
    u_int8_t run=TRUE;
    u_int16_t len=0;


    i=0;
    while (run) {
	if (i<pattlen) {
	    pitchcache[count]=pattern->Note[i].Pitch;
	    paramcache[count]=pattern->Note[i].Param;
	    switch (state) {
	    case 16:
		if (pitchcache[count]==0x00 && paramcache[count]==0x00)
		    { state=0; break;}
		if (paramcache[count]==0x00)
		    { state=1; break;}	
		if (pitchcache[count]==0x80)
		    { state=2; break;}
		state=3;
		break;
	    case 0:
		if (pitchcache[count]==0x00 && paramcache[count]==0x00)
		    { state=0+8; break;}
		state|=32;
		break;
	    case 1:
		if (pitchcache[count]==pitchcache[count-1] && paramcache[count]==0x00)
		    { state=1+8; break;}
		if (pitchcache[count]!=pitchcache[count-1] && paramcache[count]==0x00)
		    { state=5+8; break;}
		state|=32;
		break;
	    case 2:
		if (pitchcache[count]==0x80 && paramcache[count]==paramcache[count-1])
		    { state=2+8; break;}
		if (pitchcache[count]==0x80 && paramcache[count]!=paramcache[count-1])
		    { state=6+8; break;}
		state|=32;
		break;
	    case 3:
		if (pitchcache[count]==pitchcache[count-1] && paramcache[count]==paramcache[count-1])
		    { state=3+8; break;}
		if (pitchcache[count]!=pitchcache[count-1] || paramcache[count]!=paramcache[count-1])
		    { state=7+8; break;}
		state|=32;
		break;
	    case 8:
		if (pitchcache[count]==0x00 && paramcache[count]==0x00)
		    { state=0+8; break;}
		state|=32;
		break;
	    case 9:
		if (pitchcache[count]==pitchcache[count-1] && paramcache[count]==0x00)
		    { state=1+8; break;}
		state|=32;
		break;
	    case 10:
		if (pitchcache[count]==0x80 && paramcache[count]==paramcache[count-1])
		    { state=2+8; break;}
		state|=32;
		break;
	    case 11:
		if (pitchcache[count]==pitchcache[count-1] && paramcache[count]==paramcache[count-1])
		    { state=3+8; break;}
		state|=32;
		break;
	    case 13:
		if (pitchcache[count]!=pitchcache[count-1] && paramcache[count]==0x00)
		    { state=5+8; break;}
		state|=32;
		break;
	    case 14:
		if (pitchcache[count]==0x80 && paramcache[count]!=paramcache[count-1])
		    { state=6+8; break;}
		state|=32;
		break;
	    case 15:
		if (pitchcache[count]!=pitchcache[count-1] || paramcache[count]!=paramcache[count-1])
		    { state=7+8; break;}
		state|=32;
		break;
	    default:
		puts("packer: unknown state");			
		break;
	    }
	    if (debug_g>=2)
		printf("%02x: %02x %02x state %d  count %d\n",i,pitchcache[count],paramcache[count],state,count);
	} else {
	    state|=32;
	    run=FALSE;
	}

	if (state&32) {
	    patternbuffer[index++]=((state&0x07)<<5)|(count-1);
	    switch (state&0x07) {
	    case 0:
		break;
	    case 1:
		patternbuffer[index++]=pitchcache[0];
		break;
	    case 2:
		patternbuffer[index++]=paramcache[0];
		break;
	    case 3:
		patternbuffer[index++]=pitchcache[0];
		patternbuffer[index++]=paramcache[0];
		break;
	    case 4:
		puts("illegal state");
		break;
	    case 5:
		for (j=0; j<count; j++)
		    patternbuffer[index++]=pitchcache[j];
		break;
	    case 6:
		for (j=0; j<count; j++)
		    patternbuffer[index++]=paramcache[j];
		break;
	    case 7:
		for (j=0; j<count; j++) {
		    patternbuffer[index++]=pitchcache[j];
		    patternbuffer[index++]=paramcache[j];
		}
		break;
	    default:
		puts("unknown state");
		break;
	    }
	    count=0;
	    state=16;
	} else {
	    count++;
	    i++;
	}
    }

    patternbuffer[index++]=0x80;

/*
 * If we got an unresonably long pattern, just do a clone!
 */
    if (index>(pattlen*2+2)) {
	index=0;
	patternbuffer[index++]=0xe0+(pattlen-1);
	for (j=0; j<pattlen; j++) {
	    patternbuffer[index++]=pattern->Note[j].Pitch;
	    patternbuffer[index++]=pattern->Note[j].Param;
	}
	patternbuffer[index++]=0x80;
    }


    fdumpbytes(fp,patternbuffer,index,16);

    len=UnpackPattern(fp,patternbuffer,patternbuffer2);

    if ((!memcmp(pattern,patternbuffer2,pattlen*2)) && len==pattlen*2) {
	if (verbose_g)
	    printf("unpacks ok. ");
    } else {
	if (verbose_g)
	    printf("couldn't unpack! ");
	panic("couldn't unpack pattern");
    }
    if (verbose_g)
        printf("(size: $%02x)\n",index);
}


/**************************************************************************
 *
 * Unpackpattern and output to file
 *
 ******/
u_int16_t UnpackPattern(FILE *fp, u_int8_t *buffer, u_int8_t *destbuffer)
{
    u_int8_t data;
    u_int8_t t=0;
    int i=0,j=0;
    u_int8_t index=0;
    u_int8_t run=TRUE;

/* clear tables */
    for (i=0; i < 256; i++) {
	destbuffer[i]=0;
    }

    i=0;

    while(run) {
	data=buffer[i++];

	t=data&0x1f;
	switch ((data>>5)&0x07) {
	case 0:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=0;
		destbuffer[index++]=0;
	    }
	    break;
	case 1:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=buffer[i];
		destbuffer[index++]=0;
	    }
	    i++;
	    break;
	case 2:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=0x80;
		destbuffer[index++]=buffer[i];
	    }
	    i++;
	    break;
	case 3:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=buffer[i];
		destbuffer[index++]=buffer[i+1];
	    }
	    i+=2;
	    break;
	case 4:
	    run=FALSE;
	    break;
	case 5:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=buffer[i++];
		destbuffer[index++]=0;
	    }
	    break;
	case 6:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=0x80;
		destbuffer[index++]=buffer[i++];
	    }
	    break;
	case 7:
	    for (j=0; j<=t; j++) {
		destbuffer[index++]=buffer[i++];
		destbuffer[index++]=buffer[i++];
	    }
	    break;
	default:
	    panic("Unpack: error");
	    break;
	}
    }
    
    return(index);
}


/**************************************************************************
 *
 * Load a tune to buffer.
 *
 ******/
u_int8_t *LoadTune(char *filename)
{
    u_int8_t *ptr;
    int size;
    FILE *fp;

    ptr=calloc(1,sizeof(struct Tune));
    if (!ptr)
        panic("couldn't allocate memory!");

    if (!(fp=fopen(filename,"rb")))
	return(NULL);
    fseek(fp,0,SEEK_END);
    if (ferror(fp))
	return(NULL);

    size=ftell(fp);
    if (size>sizeof(struct Tune))
        panic("file to big!");

    fseek(fp,0,SEEK_SET);
    fread(ptr,size,1,fp);

    if (ferror(fp))
	return(NULL); 
    fclose(fp);

    return(ptr);
}

/**************************************************************************
 *
 * Save a tune from a buffer.
 *
 ******/
int SaveTune(char *filename, struct Tune *tune)
{
    FILE *fp;
    int size,i,j,maxpatt;

/* find the last pattern used, and calculate the size */
    maxpatt=0;
    for (i=0; i<5; i++) {
        for (j=0; j<TUNE_TABLEN; j++) {
	    int patt=tune->Tab[i].Data[j];
	    if (patt>maxpatt)
	        maxpatt=patt;
	}
    }
    size=((u_int8_t *)&(tune->Pattern[maxpatt+1]))-((u_int8_t *)tune);

/* write the file */

    if (!(fp=fopen(filename,"wb")))
	return 0;

    fwrite(tune,size,1,fp);

    if (ferror(fp))
	return 0; 
    fclose(fp);

    return -1;
}

/* eof */
