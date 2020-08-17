victracker - a musical composition tool for the Commodore vic-20 computer.

victracker is a tracker-style music editor for the Commodore vic-20.  A song
compressor/compiler is included which runs on any unix system and produces
vic-20 assembly source files.  To run victracker you need atleast 16KB
expansion memory.

The file victracker is the assembled vic-20 binary.
There are som demo songs in the directory examples.
In the vtcomp directory you will find the song compiler/compressor.

REQUIRED
  dasm-2.12.04 (by Matt Dillon, improved by Olaf Seibert)
      or any other compatible macro assembler.
  pucrunch (by Pasi Ojala)
  perl 5.003 or greater
  GNU dd
  GNU make

INSTALLING
victracker should compile on any unix-like system, just type 'make'
(or 'gmake' on some systems)

To transfer the resulting binary to your vic-20 you can for example
use Over5 (by Daniel Kahlin).  
These utilities can be found at http://www.kahlin.net/daniel/over5/

/Daniel Kahlin <daniel@kahlin.net>
