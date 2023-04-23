#ifdef CPM
#define CHK_SHOW_VERSION(argc, argv)
#else
#include <stdio.h>
#include <stdbool.h>

typedef char const verstr[];
#ifdef _MSC_VER
#ifndef strcasecmp
#define strcasecmp _stricmp
#define strncasecmp _strnicmp
#endif
#endif

void showVersion(bool full);
#define CHK_SHOW_VERSION(argc, argv) \
    if (argc == 2 && strcasecmp(argv[1], "-v") == 0) { \
        showVersion(argv[1][1] == 'V'); \
        exit(0); \
    }
#endif
