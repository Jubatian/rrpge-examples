
RRPGE Example applications
==============================================================================

:Author:    Sandor Zsuga (Jubatian)
:Copyright: 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
            License) extended as RRPGEvt (temporary version of the RRPGE
            License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
            root.




Introduction
------------------------------------------------------------------------------


A mix of simple to complex example applications to demonstrate the features of
RRPGE, and to provide guidance for programming the RRPGE CPU.

Currently transition is ongoing in accordance to Specification 00.011.003 and
the oncoming 00.012.000. New, or rewised examples are released under the
Temporary RRPGE License.

As of now only the following examples are functional: ::

    simplegf
    mouse


Temporary license notes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Currently the project is developed under a temporary GPL compatible license.
The intention for later is to add some permissive exceptions to this license,
allowing for creating derivative works (most importantly, applications) under
other licenses than GPL.

For more information, see http://www.rrpge.org/community/index.php?topic=30.0




Build instructions
------------------------------------------------------------------------------


Use the RRPGE Assembler in each of the directories. By default (without
parameters) it will take the "main.asm" file, compile the application, and
produce an "app.rpa" which can be started by an RRPGE implementation.




The examples
------------------------------------------------------------------------------


Binary data (data)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Demonstrates the use of extra binary data in the application binary, showing
how this data may be loaded, and used to display a 320x400 image.


GDG Sprites (gdgsprit)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A small intro scene utilizing the Graphics Display Generator, mostly producing
sprites. This example also contains some ready to use libraries:

- Copy (copy.asm): A generic copy capable to copy any amount of data between
  any two locations, utilizing DMA where possible.

- RLE decoder (rledec.asm): A simple RLE decoder used to decode image data for
  the 16 color display. An encoder for this format is provided in the
  makerle.c source.

- GDG sprite library (gdgsprit.asm; gdgspfix.asm): A complete sprite library
  for the Graphics Display Generator, designed to be useful with a graphics
  engine utilizing the Accelerator as well.


Mixer (mixer)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Shows basic audio mixer usage, also demonstrating the use of some built-in
sample data.


Mouse (mouse)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A very simple example program demonstrating the use of a mouse.


Noise (noise)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The most basic example program producing noise. This program may be one of the
firsts when testing a new RRPGE implementation, requiring the least from the
host.


Proportional text (proptext)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Proportional text output using the Graphics Accelerator. It contains several
small libraries to achieve it's goals:

- Copy (copy.asm): A generic copy capable to copy any amount of data between
  any two locations, utilizing DMA where possible.

- Blitter (blit.asm; blitnc.asm; blitsupp.asm): Generic blitter useful for
  most types of Block Blitter usage, such as working with Accelerator sprites.

- Text (textblit.asm; textlgen.asm): Proportional text output capable to build
  multi-line texts with left, right, center or justify alignments with some
  support for text formatting.

- Compact 1bit font definition (fontdef1.asm): A font definition expander
  which may be used for saving some bits of storage space compared to storing
  a full 256 * 4 Word font definition.


Rotozoomer (rotozoom)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A rotozoomer demonstrating some uses of the Graphics Accelerator. This example
also contains some limited use libraries:

- Rotozoomer (effrzoom.asm): Produces a rotozoomer into an arbitrary
  destination from a fixed full 1024x512 VRAM bank. It might work for double
  scanned 8bit mode (320x200) as well, not tested.

- Horizontal wave (effwave.asm): Produces a wave effect by altering a column
  of render commands in a display list. It is not compatible with the GDG
  sprite library in the GDG sprite example.

- RLE decoder (rledec.asm): A simple RLE decoder used to decode image data for
  the 16 color display. An encoder for this format is provided in the
  makerle.c source.
