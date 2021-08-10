// generate version strings
#ifdef AUTOVER                      // defined if we are using version.cmd script with Git
#include "Generated/version.h"
#else
#include "version.in"
#endif
// determine the target bit width
#if defined _M_X64 || (defined __x86_64 && !defined __IPL32__)
#define ARCHSIZE   "64bit"
#else
#define ARCHSIZE   "32bit"
#endif

// and whether it is a debug build
#ifdef _DEBUG
#define BUILD   "{ " ARCHSIZE " debug }"
#else
#define BUILD   "{ " ARCHSIZE " }"
#endif

// convert the GIT_BUILDTYPE into a string
#if GIT_BUILDTYPE == 2
#define DIRTY   " +uncommitted files"
#elif GIT_BUILDTYPE == 3
#define DIRTY   " -untracked files"
#else
#define DIRTY
#endif

// the generate the normal version string
// there are two flavours depending on whether the code is a port
// if it is add a #define GIT_PORT "string" in version.in
// string would typically be of the form
// "x.y (C) company"
// e.g. "2.2 (C) Whitesmiths"
#ifdef GIT_PORT
static const char *git_ver = GIT_APPNAME " [ " GIT_PORT " ] - " BUILD " " GIT_VERSION " port (C)" GIT_YEAR " Mark Ogden";
#else
static const char *git_ver = GIT_APPNAME " - " BUILD " " GIT_VERSION " (C)" GIT_YEAR " Mark Ogden";
#endif

const char *git_detail = GIT_APPNAME " " GIT_VERSION "  " GIT_SHA1 "  [" GIT_CTIME "]" DIRTY;


// show version information

#include <stdio.h>
#include <stdbool.h>

// optional library includes

const char **git_details[] = {
    &git_detail,
    // insert library details here before NULL
    NULL
};

// use the following function declaration in the main code
// void showVersion(FILE *fp, bool full);

void showVersion(FILE *fp, bool full) {
    fputs(git_ver, fp);
    fputc('\n', fp);
    if (full) {
        fputs("Git Info:\n", fp);
        for (const char ***s = git_details; *s; s++) {
            fputs(**s, fp);
            fputc('\n', fp);
        }
    }
}


