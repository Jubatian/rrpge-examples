/**
**  \file
**  \brief     Font image data binary creator
**  \author    Sandor Zsuga (Jubatian)
**  \copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
**             License) extended as RRPGEv2 (version 2 of the RRPGE License):
**             see LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
**  \date      2014.05.02
**
**
**  Creates font image binary data from Gimp header.
**
**  First using Gimp's C header output feature a "data.h" file should be
**  generated. If this is not available, the used "header_data" array from it
**  is simply a flat linear 8 bit image data. Only the lowest bit of each
**  pixel is used, set bits becoming transparent pixels of the font, clear
**  bits becoming solid pixels. The "width" and "height" constants in the
**  "data.h" header specify the dimensions of the image.
**
**  The source image in Gimp must contain 4 rows of fonts. The topmost row
**  will be the resulting binary's bottomost bit, and so on overlaying 4 bit
**  planes. The height of the image can be arbitrary, 4 times more than the
**  intended height of the font. The width must be dividable by 8 (8 pixels
**  form one VRAM cell in RRPGE).
*/

#include <stdio.h>
#include <stdlib.h>
#include "data.h"


int main(int argc, char** argv)
{
 int dlen = (width * height) >> 2;
 int i;
 unsigned char c;

 for (i = 0; i < dlen; i+=2){
  c = ((header_data[i                 ] & 1) << 4) |
      ((header_data[i +      dlen     ] & 1) << 5) |
      ((header_data[i +     (dlen * 2)] & 1) << 6) |
      ((header_data[i +     (dlen * 3)] & 1) << 7) |
      ((header_data[i + 1             ] & 1)     ) |
      ((header_data[i + 1 +  dlen     ] & 1) << 1) |
      ((header_data[i + 1 + (dlen * 2)] & 1) << 2) |
      ((header_data[i + 1 + (dlen * 3)] & 1) << 3);
  fwrite(&c, 1, 1, stdout);
 }

 return 0;
}
