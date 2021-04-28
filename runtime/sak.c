/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                 David Allsopp, OCaml Labs, Cambridge.                  */
/*                                                                        */
/*   Copyright 2021 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Runtime Builder's Swiss Army Knife */

#define CAML_INTERNALS
#include "caml/misc.h"

#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>

#ifdef HAS_UNISTD
#include <unistd.h>
#endif

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#define lseek _lseeki64
#endif

#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif

#ifndef _O_BINARY
#define _O_BINARY 0
#endif
#ifndef _O_TEXT
#define _O_TEXT 0
#endif

#ifdef _WIN32
#define WRITE_TEXT_FILE T("wt")
#define printf_os wprintf
#define strchr_os wcschr
#define sscanf_os swscanf
#else
#define WRITE_TEXT_FILE T("w")
#define printf_os printf
#define strchr_os strchr
#define sscanf_os sscanf
#endif

void usage(void)
{
  printf(
    "OCaml Build System Swiss Army Knife\n"
    "Usage: sak command\n"
    "Commands:\n"
    " * primitives - generates primitives and prims.c in current dir\n"
    " * opnames - generates opnames.inc and jumptbl.inc from caml/instruct.h\n"
    " * version string - generates version.h from the given string\n"
    " * domain_state32 - generates domain_state32.inc from domain_state.tbl\n"
    " * domain_state64 - generates domain_state64.inc from domain_state.tbl\n"
  );
}

char *read_file(char_os *path)
{
  char *result = NULL, *buf;
  int flags = O_RDONLY | _O_BINARY;
  int fd, size, nbytes;

  if ((fd = open_os(path, flags, 0)) == -1)
    return NULL;

  if ((size = lseek(fd, 0, SEEK_END)) == -1)
    goto error;

  if (lseek(fd, 0, SEEK_SET) == -1)
    goto error;

  if ((result = buf = (char *)malloc(size + 1)) == NULL)
    goto error;

  result[size] = 0;

  while (size > 0) {
    if ((nbytes = read(fd, buf, size)) == -1) {
      if (errno != EAGAIN)
        goto abort;
    } else {
      size -= nbytes;
      buf += nbytes;
    }
  }

  close(fd);

  return result;

abort:
  free(result);
error:
  close(fd);
  return NULL;
}

void die(const char* format, ...)
{
  va_list args;
  fputs("Fatal error: ", stderr);
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  exit(1);
}

int qsort_strcmp(const void *l, const void *r)
{
  return strcmp(*(const char**)l, *(const char**)r);
}

char *scan_to_eol(char *p)
{
  char *q = p, *r;
  while (*q != 0 && *q != '\n')
    q++;
  r = q;
  /* If not at the end of the buffer, advance to next character */
  if (*r != 0)
    r++;
  while (q > p && *(q - 1) == '\r')
    q--;
  /* q now points to the first character of \r*\n at the end of the line */
  *q = 0;
  return r;
}

void harvest_primitives(void)
{
  char_os *files[] =
    /* ints.c gets special handling and must be first */
    {T("ints.c"), T("alloc.c"), T("array.c"), T("compare.c"), T("extern.c"),
     T("floats.c"), T("gc_ctrl.c"), T("hash.c"), T("intern.c"), T("interp.c"),
     T("io.c"), T("lexing.c"), T("md5.c"), T("meta.c"), T("memprof.c"),
     T("obj.c"), T("parsing.c"), T("signals.c"), T("str.c"), T("sys.c"),
     T("callback.c"), T("weak.c"), T("finalise.c"), T("stacks.c"),
     T("dynlink.c"), T("backtrace_byt.c"), T("backtrace.c"), T("afl.c"),
     T("bigarray.c"), T("eventlog.c"), NULL};
  char_os *current;
  char *content, *p, *q;
  char **prims;
  int i = 0, nb_prims = 1, sz_prims = 512, scan_int64 = 1;
  FILE* fp;
#ifdef _WIN32
  struct _stati64 st;
#else
  struct stat st;
#endif
  int emit_prims = (stat_os(T("prims.c"), &st) == -1);
  int emit_primitives = 1;
  prims = (char **)malloc(sz_prims * sizeof(char*));
  prims[0] = "";
  while ((current = files[i++]) != NULL) {
    if ((content = p = read_file(current)) != NULL) {
      while (*p != 0) {
        if (!strncmp(p, "CAMLprim value ", 15)) {
          /* Found start of a primitive name */
          p += 15;
          q = p;
          /* Find the end of the primitive name */
          while (*q != 0 && (isalnum(*q) || *q == '_'))
            q++;
          if (*q == 0)
            die("unexpected end of \"%s\"", current);
          *q = 0;
          /* Store the primitive name */
          prims[nb_prims++] = strdup(p);
          p = q + 1;
        } else if (scan_int64 && !strncmp(p, "CAMLprim_int64_", 15)) {
          p += 15;
          if ((*p == '1' || *p == '2') && *++p == '(') {
            q = ++p;
            /* Find the end of the primitive name */
            while (*q != 0 && (isalnum(*q) || *q == '_'))
              q++;
            if (*q == 0)
              die("unexpected end of \"%s\"", current);
            *q = 0;
            if ((prims[nb_prims] = (char *)malloc(12 + q - p)) == NULL ||
                (prims[nb_prims + 1] = (char *)malloc(19 + q - p)) == NULL)
              die("out of memory");
            sprintf(prims[nb_prims++], "caml_int64_%s", p);
            sprintf(prims[nb_prims++], "caml_int64_%s_native", p);
            p = q + 1;
          }
        }
        /* Find the end of the line */
        p = scan_to_eol(p);
        /* p either at the end of the file or at the character following the
           newline. */
      }
      /* Ensure there's capacity for at least two primitives */
      if (nb_prims + 1 >= sz_prims) {
        sz_prims += 512;
        if ((prims = (char **)realloc(prims, sz_prims)) == NULL)
          die("out of memory");
      }
      free(content);
      scan_int64 = 0;
    } else {
      die("out of memory");
    }
  }
  /* Sort the primitives */
  qsort(prims, nb_prims, sizeof(char *), qsort_strcmp);
  if ((fp = fopen_os(T("primitives.new"), WRITE_TEXT_FILE)) == NULL)
    die("failed to open primitives.new for writing");
  for (i = 1; i < nb_prims; i++) {
    if (strcmp(prims[i - 1], prims[i])) {
      fprintf(fp, "%s\n", prims[i]);
    } else {
      *prims[i] = 0;
    }
  }
  fclose(fp);
  if ((p = read_file(T("primitives"))) != NULL) {
    if ((q = read_file(T("primitives.new"))) == NULL)
      die("failed to read primitives.new back");
    if (!strcmp(p, q)) {
      unlink("primitives.new");
      emit_primitives = 0;
    } else {
      emit_prims = 1;
    }
    free(p);
    free(q);
  } else {
    emit_prims = 1;
  }
  if (emit_prims) {
    if ((fp = fopen_os(T("prims.c"), WRITE_TEXT_FILE)) == NULL)
      die("failed to open prims.c for writing");
    fputs("#define CAML_INTERNALS\n"
          "#include \"caml/mlvalues.h\"\n"
          "#include \"caml/prims.h\"\n", fp);
    for (i = 1; i < nb_prims; i++)
      if (*prims[i] != 0)
        fprintf(fp, "extern value %s();\n", prims[i]);
    fputs("c_primitive caml_builtin_cprim[] = {\n", fp);
    for (i = 1; i < nb_prims; i++)
      if (*prims[i] != 0)
        fprintf(fp, "  %s,\n", prims[i]);
    fputs("  0 };\n"
          "char * caml_names_of_builtin_cprim[] = {\n", fp);
    for (i = 1; i < nb_prims; i++)
      if (*prims[i] != 0)
        fprintf(fp, "  \"%s\",\n", prims[i]);
    fputs("  0 };\n", fp);
    fclose(fp);
  }
  i = 0;
  while (++i < nb_prims)
    free(prims[i]);
  free(prims);
  if (emit_primitives)
    puts("primitives.new");
}

void process_instruct(void)
{
  char *content, *p, *q, *space;
  FILE *opnames, *jumptbl;
  int state = 0;
  if ((content = p = read_file(T("caml/instruct.h"))) == NULL)
    die("Failed to read caml/instruct.h");
  if ((opnames = fopen_os(T("opnames.inc"), WRITE_TEXT_FILE)) == NULL)
    die("Failed to open opnames.inc for writing");
  if ((jumptbl = fopen_os(T("jumptbl.inc"), WRITE_TEXT_FILE)) == NULL)
    die("Failed to open jumptbl.inc for writing");
  while (*p != 0) {
    q = scan_to_eol(p);
    /* Ignore blank lines, lines beginning # or with a comment-opening and
       single-line characters. */
    if (*p != 0 && *(p + 1) != 0 && *p != '#' && strncmp(p, "/*", 2)) {
      if (state == 0 && !strncmp(p, "enum ", 5)) {
        p += 5;
        if ((space = strchr(p, ' ')) == NULL)
          die("cannot parsing enum line of caml/instruct.h");
        *space = 0;
        fprintf(opnames, "static char * names_of_%s[] = {\n", p);
        fputs("static void * jumptable[] = {\n", jumptbl);
        state = 1;
      } else if (state > 0 && *p == ' ') {
        /* Convert enum constants to strings */
        if (state > 1) {
          fputs(",\n", opnames);
          fputs(",\n", jumptbl);
        } else {
          state = 2;
        }
        while (*p != 0) {
          while (*p != 0 && !isupper(*p)) {
            fputc(*p, opnames);
            fputc(*p, jumptbl);
            p++;
          }
          fputc('"', opnames);
          fputs("&&lbl_", jumptbl);
          while (*p != 0 && *p != ',') {
            fputc(*p, opnames);
            fputc(*p, jumptbl);
            p++;
          }
          if (*p == 0)
            die("unexpected eol processing caml/instruct.h");
          p++;
          fputc('"', opnames);
          if (*p != 0) {
            fputc(',', opnames);
            fputc(',', jumptbl);
          }
        }
      }
    }
    p = q;
  }
  if (state != 2)
    die("error parsing caml/instruct.h");
  fputs("\n};\n", opnames);
  fputs("\n};\n", jumptbl);
  fclose(opnames);
  fclose(jumptbl);
  free(content);
}

void convert_version(char_os *content)
{
  char_os *p, *q;
  int major, minor, patchlvl, read;

  printf_os(T("#ifndef CAML_VERSION_H\n")
            T("#define CAML_VERSION_H\n")
            T("#define OCAML_VERSION_STRING \"%s\"\n"), content);

  p = strchr_os(content, '+');
  q = strchr_os(content, '~');
  if (p == NULL || (q != NULL && q < p))
    p = q;

  /* If p isn't NULL then it points to the first + or ~ in content. Set that
     to NULL to terminate the string passed to scanf and leave p pointing to
     the additional info.
     */
  if (p != NULL && *p != 0)
    *p++ = 0;
  if (p != NULL && *p != 0)
    printf_os(T("#define OCAML_VERSION_ADDITIONAL \"%s\"\n"), p);
  else
    printf_os(T("#undef OCAML_VERSION_ADDITIONAL\n"));

  if (sscanf_os(content, T("%u.%u.%u%n"), &major, &minor, &patchlvl, &read) == 3
      && read == strlen_os(content)) {
    printf_os(T("#define OCAML_VERSION_MAJOR %d\n")
              T("#define OCAML_VERSION_MINOR %d\n")
              T("#define OCAML_VERSION_PATCHLEVEL %d\n")
              T("#define OCAML_VERSION %d%02d%02d\n")
              T("#endif /*CAML_VERSION_H*/\n"),
              major, minor, patchlvl, major, minor, patchlvl);
  } else {
    die("unable to parse the version number");
  }
}

void domain_state32(int count, char *name)
{
  printf("Store_%2$s MACRO reg1, reg2\n"
         "  mov [reg1+%1$d], reg2\n"
         "ENDM\n"
         "Load_%2$s MACRO reg1, reg2\n"
         "  mov reg2, [reg1+%1$d]\n"
          "ENDM\n"
         "Push_%2$s MACRO reg1\n"
         "  push [reg1+%1$d]\n"
         "ENDM\n"
         "Pop_%2$s MACRO reg1\n"
         "  pop [reg1+%1$d]\n"
         "ENDM\n"
         "Cmp_%2$s MACRO reg1, reg2\n"
         "  cmp reg2, [reg1+%1$d]\n"
         "ENDM\n"
         "Sub_%2$s MACRO reg1, reg2\n"
         "  sub reg2, [reg1+%1$d]\n"
         "ENDM\n", count, name);
}

void domain_state64(int count, char *name)
{
  printf("Store_%2$s MACRO reg\n"
         "  mov [r14+%1$d], reg\n"
         "ENDM\n"
         "Load_%2$s MACRO reg\n"
         "  mov reg, [r14+%1$d]\n"
          "ENDM\n"
         "Push_%2$s MACRO\n"
         "  push [r14+%1$d]\n"
         "ENDM\n"
         "Pop_%2$s MACRO\n"
         "  pop [r14+%1$d]\n"
         "ENDM\n"
         "Cmp_%2$s MACRO reg\n"
         "  cmp reg, [r14+%1$d]\n"
         "ENDM\n", count, name);
}

void process_domain_state(void (*emit)(int, char *))
{
  char *content, *p, *q, *name;
  int count = 0;

  if ((p = content = read_file(T("caml/domain_state.tbl"))) == NULL)
    die("unable to read caml/domain_state.tbl");

  /* MSVC doesn't support the 'm' modifier in sscanf */
  name = (char *)malloc(strlen(content));

  while (*p != 0) {
    q = scan_to_eol(p);

   printf("Got %s\n", p);
    if (sscanf(p, "DOMAIN_STATE(%*[^,],%*[ ]%[^)])", name) == 1) {
      printf("Processing %s\n", name);
      emit(count, name);
      count += 8;
    }

    /* Process next line */
    p = q;
  }

  free(content);
  free(name);
}

#ifdef _WIN32
int wmain(int argc, wchar_t **argv)
#else
int main(int argc, char **argv)
#endif
{
  if (argc == 2 && !strcmp_os(argv[1], T("primitives"))) {
    harvest_primitives();
  } else if (argc == 2 && !strcmp_os(argv[1], T("opnames"))) {
    process_instruct();
  } else if (argc == 3 && !strcmp_os(argv[1], T("version"))) {
    convert_version(argv[2]);
  } else if (argc == 2 && !strcmp_os(argv[1], T("domain_state32"))) {
    process_domain_state(&domain_state32);
  } else if (argc == 2 && !strcmp_os(argv[1], T("domain_state64"))) {
    process_domain_state(&domain_state64);
  } else {
    usage();
    return 1;
  }

  return 0;
}
