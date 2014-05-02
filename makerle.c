/**
**  \file
**  \brief     RLE binary creator
**  \author    Sandor Zsuga (Jubatian)
**  \copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
**             License) extended as RRPGEv2 (version 2 of the RRPGE License):
**             see LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
**  \date      2014.05.02
**
**
**  First using Gimp's C header output feature a "data.h" file should be
**  generated. If this is not available, the used "header_data" array from it
**  is simply a flat linear 8 bit image data. Only the lowest 2 bits of each
**  pixel are used. The "width" and "height" constants in the "data.h" header
**  specify the dimensions of the image.
**
**  Produces an RLE encoded binary to the standard output (use console output
**  redirection to write it into a file). The format is as follows:
**
**  An unit is of 4 bits size, they follow each other in Big Endian order.
**
**  Low 2 bits specify pixel color.
**  High 2 bits specify count or special use as follows:
**  1: 1px
**  2: 2px
**  3: 3px
**  0: Next 4 bits are used for further sizes:
**  0: 16px (2 ^ 4)
**  1: 32px (2 ^ 5)
**  ...
**  6: 1024px (2 ^ 10)
**  7: 7px
**  8: 8px
**  ...
**  15: 15px
**
**  The program only uses the image dimension data ("width" and "height") to
**  calculate the count of elements to encode, the RLE encoding does not break
**  at image line ends.
*/

#include <stdio.h>
#include <stdlib.h>
#include "data.h"


int main(int argc, char** argv)
{
 int dlen = width * height;
 int sp = 0;
 int i;
 int n;
 unsigned char c;
 unsigned char r;
 unsigned char fo;
 int fp = 0;

 while (1){

  /* Collect a run of pixels */
  r = (header_data[sp] & 3U);
  i = 1;
  while (1){
   if ((sp + i) == dlen){ break; }
   if (r != (header_data[(sp + i)] & 3U)){ break; }
   i++;
  }

  /* Encode the run */
  if (i < 7){
   if (i > 3){ i = 3; }
   c = r + (i << 2);
   n = 0;
  }else if (i < 16){
   c = (r << 4) + i;
   n = 1;
  }else{
   c = (r << 4);
   if      (i <   32){ i =   16; c |= 0U; }
   else if (i <   64){ i =   32; c |= 1U; }
   else if (i <  128){ i =   64; c |= 2U; }
   else if (i <  256){ i =  128; c |= 3U; }
   else if (i <  512){ i =  256; c |= 4U; }
   else if (i < 1024){ i =  512; c |= 5U; }
   else              { i = 1024; c |= 6U; }
   n = 1;
  }

  /* Add up source */
  sp += i;

  /* Generate output */
  if       ((fp == 0) && (n == 0)){
   fo  = c << 4;
   fp  = 1;
  }else if ((fp != 0) && (n == 0)){
   fo |= c;
   fwrite(&fo, 1, 1, stdout);
   fp  = 0;
  }else if ((fp == 0) && (n != 0)){
   fo  = c;
   fwrite(&fo, 1, 1, stdout);
  }else{
   fo |= (c >> 4);
   fwrite(&fo, 1, 1, stdout);
   fo  = (c << 4);
  }

  /* Check end */
  if (sp == dlen){ break; }

 }

 /* Write out last half nybble if any */
 if (fp != 0){
  fwrite(&fo, 1, 1, stdout);
 }

 return 0;
}
