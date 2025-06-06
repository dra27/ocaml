/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*            David Allsopp, University of Cambridge & Tarides            */
/*                                                                        */
/*   Copyright 2025 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Micro-program used to sit in PATH to test local path search for bytecode
   executables. */

#include <stdio.h>

#ifdef _WIN32
int wmain(int argc, wchar_t **argv)
#else
int main(int argc, char **argv)
#endif
{
  printf("The poisoned runtime has been invoked!\n"
         "This suggests something is wrong in stdlib/header.c\n");
  return 1;
}
