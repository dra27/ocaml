@rem ***********************************************************************
@rem *                                                                     *
@rem *                                 OCaml                               *
@rem *                                                                     *
@rem *                        David Allsopp, Tarides                       *
@rem *                                                                     *
@rem *   Copyright 2023 David Allsopp Ltd.                                 *
@rem *                                                                     *
@rem *   All rights reserved.  This file is distributed under the terms    *
@rem *   of the GNU Lesser General Public License version 2.1, with the    *
@rem *   special exception on linking described in the file LICENSE.       *
@rem *                                                                     *
@rem ***********************************************************************

@setlocal
@echo off

if not defined MSYSTEM set MSYSTEM=MINGW64
if not defined MSYS2_PATH_TYPE set MSYS2_PATH_TYPE=minimal
set CHERE_INVOKING=1
D:\msys64\usr\bin\bash.exe -leo pipefail %*
