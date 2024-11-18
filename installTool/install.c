#include <ctype.h>
#include <direct.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/utime.h>
#include <time.h>

#include "support.h"

#define MAXLINE 1024

#ifdef _WIN32
#define DIRSEP            "\\/"
#define mkdir(name, mode) _mkdir(name)
#else
#define DIRSEP "/"
#endif

char const help[] = "Usage: %s source root [configFile]\n"
                    "Where\n"
                    "  source       is the file to be installed\n"
                    "  root         is the solution level directory where install.cfg is found\n"
                    "  configFile   sets an alternative configuation file from install.cfg\n";

char dst[_MAX_PATH];

char nowDate[] = "yyyymmdd";
char nowTime[] = "hhmmss";

char *joinPath(char const *path, char const *name) {
    int lenPath = (int)strlen(path);
    char *full  = safeMalloc(lenPath + strlen(name) + 2);
    strcpy(full, path);
    char *s = full + lenPath;
    if (lenPath && s[-1] != '/' && s[-1] != '\\')
        strcpy(s, "/");
    strcat(s, name);
    return full;
}

//. utility to create dir if necessary
// returns false if name is already used but not a dir
// or cannot create dir otherwise returns true
bool safeMkdir(char const *dir) {
    struct stat info;
    if (stat(dir, &info) == 0)
        return (info.st_mode & S_IFDIR);
    return mkdir(dir, 0774) == 0;
}

// mkPath is mkdir with all intermediate directories
// created if necessary. Returns true if path created
bool mkPath(char *file) {
    char *s = file;

#ifdef _WIN32
    if (s[0] && s[1] == ':')
        s += 2;
#endif
    if (strchr(DIRSEP, *s)) // don't want to try to create root
        s++;
    while (s = strpbrk(s, DIRSEP)) {
        char ch = *s;
        *s      = '\0';
        if (!safeMkdir(file)) {
            warn("Could not make directory %s", file);
            *s = ch;
            return false;
        }
        *s = ch;
        s++;
    }
    return true;
}

char const *getToken(char **plist) {
    char *list = *plist;
    while (isspace(*list))
        list++;
    char const *token = list;

    while (*list && *list != ',' && !isspace(*list))
        list++;
    char *end = list;
    while (isspace(*list))
        list++;
    if (*list == ',')
        list++;
    *plist = list;
    *end   = '\0';
    return token;
}

bool contains(char *list, char const *file) {
    while (*list) {
        char const *tok = getToken(&list);
        if (strcmp(tok, "*") == 0 || stricmp(tok, file) == 0)
            return true;
    }
    return false;
}

void initDate() {
    time_t tval;
    time(&tval);
    struct tm *timeInfo = localtime(&tval);
    sprintf(nowDate, "%04d%02d%02d", timeInfo->tm_year + 1900, timeInfo->tm_mon + 1,
            timeInfo->tm_mday);
    sprintf(nowTime, "%02d%02d%02d", timeInfo->tm_hour, timeInfo->tm_min, timeInfo->tm_sec);
}

bool copyFile(char const *src, char *dst) {
    if (!mkPath(dst))
        return false;
    struct stat sinfo; // for timestamps
    FILE *sfp = fopen(src, "rb");
    if (!sfp || fstat(fileno(sfp), &sinfo))
        fatal("Cannot access %s", src);

    FILE *dfp = fopen(dst, "wb");
    if (!dfp) {
        fclose(sfp);
        warn("Cannot create %s", dst);
        return false;
    }

    char block[4096];
    int actual;
    while ((actual = (int)fread(block, 1, sizeof(block), sfp)))
        if (fwrite(block, 1, actual, dfp) != actual)
            fatal("Copy failed");
    fclose(sfp);
    fclose(dfp);
    struct utimbuf times = { .actime = sinfo.st_atime, .modtime = sinfo.st_mtime };
    utime(dst, &times);
    return true;
}

char *addStr(char *dst, char const *src) {
    while (*dst = *src++)
        dst++;
    return dst;
}

int install(char const *cfgFile, char const *source, char const *root) {
    if (!cfgFile || !*cfgFile)
        cfgFile = joinPath(root, "install.cfg");

    char *srcDup     = safeStrdup(source);
    char const *file = basename(srcDup);
    char const *parent;
    if (file == srcDup) {
        warn("source should include parent directory");
        parent = "";
    } else {
        char *s = (char *)file;
        s[-1]   = '\0';
        parent  = basename(srcDup);
    }
    if (!*parent)
        parent = ".";

    bool skip = false;

    FILE *fp  = fopen(cfgFile, "rt");
    if (!fp)
        fatal("Cannot open configuration file %s", cfgFile);

    char line[MAXLINE];
    int result = 0;
    while (fgets(line, MAXLINE, fp)) {
        char *lp = line;
        while (isspace(*lp))
            lp++;
        if (*lp == '-' && contains(lp + 1, file))
            skip = true;
        else if (*lp == '+' && contains(lp + 1, file))
            skip = false;
        else if (!skip && *lp != '*' && stricmp(getToken(&lp), parent) == 0) {
            char const *target = getToken(&lp);
            char const *suffix = getToken(&lp);
            if (*target == '+')
                target = joinPath(root, target + 1);
            char *t = dst;
            for (char const *s = target; *s; s++) {
                if (*s == '$' && (s[1] == 'd' || s[1] == 't'))
                    t = addStr(t, *++s == 'd' ? nowDate : nowTime);
                else
                    *t++ = *s;
            }
            if (t != dst && !strchr(DIRSEP, t[-1]))
                *t++ = DIRSEP[0];
            for (char const *s = file; *s; s++) {
                if (*s == '$' && (s[1] == 'd' || s[1] == 't'))
                    t = addStr(t, *++s == 'd' ? nowDate : nowTime);
                else {
                    if (*s == '.' && *suffix && stricmp(s, ".exe") == 0)
                        t = addStr(t, suffix);
                    *t++ = *s;
                }
            }
            *t = '\0';
            if (copyFile(source, dst))
                printf("installed %s -> %s\n", file, dst);
            else {
                result = 1;
                warn("Failed to install %s -> %s", file, dst);
            }
        }
    }
    return result;
}

int main(int argc, char **argv) {

    chkStdOptions(argc, argv);
    if (argc < 3 || argc > 4)
        usage("Incorrect usage");
    char const *source     = argv[1];
    char const *root       = argv[2];
    char const *configFile = argc == 4 ? argv[3] : NULL;
    initDate();
    return install(configFile, source, root);
}