
RRPGE Example applications
==============================================================================

.. image:: https://cdn.rawgit.com/Jubatian/rrpge-spec/00.013.002/logo_txt.svg
   :align: center
   :width: 100%

:Author:    Sandor Zsuga (Jubatian)
:Copyright: 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
            License) extended as RRPGEvt (temporary version of the RRPGE
            License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
            root.




Introduction
------------------------------------------------------------------------------


A mix of simple to complex example applications to demonstrate the features of
RRPGE, and to provide guidance for programming the RRPGE CPU.


Related projects
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

- RRPGE home: http://www.rrpge.org
- RRPGE Specification: https://www.github.com/Jubatian/rrpge-spec
- RRPGE Assembler: https://www.github.com/Jubatian/rrpge-asm
- RRPGE Emulator & Library: https://www.github.com/Jubatian/rrpge-libminimal
- RRPGE User Library: https://www.github.com/Jubatian/rrpge-userlib


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


Mouse (mouse)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A very simple example program demonstrating the use of a mouse.


Noise (noise)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The most basic example program producing noise. This program may be one of the
firsts when testing a new RRPGE implementation, requiring the least from the
host.


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
