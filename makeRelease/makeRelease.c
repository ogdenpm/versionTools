// popen.c
/* This program uses _popen and _pclose to receive a
 * stream of text from a system process.
 */
#include <ctype.h>
#include <direct.h>
#include <inttypes.h>
#include <process.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

#include "support.h"

char const help[]    = "Usage:  %s [options]\n"
                       "Where options are:\n"
                       "  -r rev  use the specified revision for the new version file\n"
                       "  -m msg  use msg as the commit msg\n"
                       "  -c file set alternative configuration file instead of version.in\n"
                       "  -d      show debugging information\n";

char const *message  = "";
char const *revision = "";
bool force           = false;

char messageStr[256];

char const *configFile = "version.in";
char *versionFile;

char authorDate[32]      = "--date=seconds since epoch";

char tagPattern[128]     = "appName-r[1-9]*"; // updated once appName known
char tagPrefix[128]      = "appName-r";       // updated once appName known

char const *branchCmd[]  = { "git", "branch", "--show-current", NULL };
char const *tagListCmd[] = { "git", "tag", "-l", "-i", tagPattern, NULL };
char const *tagDate[]    = { "git", "log", "-1", "--format=%ct", tagPrefix, NULL };
char const *addCmd[]     = { "git", "add", NULL, NULL };
int addPathIndex;
char const *diffIndexCmd[]   = { "git", "diff-index", "--ignore-cr-at-eol", "--quiet", "HEAD", "--", ".", NULL };
char const *commitAmendCmd[] = { "git", "commit", "--amend", authorDate, "--", ".", NULL };
char const *commitEditCmd[]  = {
    "git", "commit", "-m", messageStr, "-e", authorDate, "--", ".", NULL
};
char const *commitCmd[] = { "git", "commit", "-m", messageStr, authorDate, "--", ".", NULL };
char const *tagCmd[]    = { "git", "tag", "-a", "-f", "-m", messageStr, tagPrefix, NULL };

time_t timeNow;

#define MAXLINE 256
char logBuf[MAXLINE];

bool debug;
bool replace;
char *appName;
char version[256];
int versionLoc = 0;
char date[20];
char oldVersion[256];

typedef struct {
    uint16_t rev;
    char qualifier[16];
    uint16_t subrev;
} tag_t;

static bool isPrefix(char const *str, char const *prefix) {
    while (*prefix && *str++ == *prefix++)
        ;
    return *prefix == '\0';
}

static char *getAppName(void) {
    char *cwd = getcwd(NULL, 260);
    if (!cwd) {
        fprintf(stderr, "Can't determine current directory\n");
        exit(1);
    }
    char *appName = safeStrdup(basename(cwd));
    free(cwd);
    return appName;
}

static void initDates() {

    time(&timeNow);
    struct tm *timeInfo = gmtime(&timeNow);
    sprintf(date, "%04d-%02d-%02d %02d:%02d:%02d", timeInfo->tm_year + 1900, timeInfo->tm_mon + 1,
            timeInfo->tm_mday, timeInfo->tm_hour, timeInfo->tm_min, timeInfo->tm_sec);
    sprintf(authorDate, "--date=%llu", timeNow);
    sprintf(version, "%04d.%d.%d.", timeInfo->tm_year + 1900, timeInfo->tm_mon + 1,
            timeInfo->tm_mday);
}

static bool parseRevision(char const *tag, tag_t *p) {
    p->rev = 0;
    while (isdigit(*tag))
        p->rev = p->rev * 10 + *tag++ - '0';
    char *t = p->qualifier;
    while (isalpha(*tag) || *tag == '_')
        *t++ = *tag++;
    *t++      = '\0';
    p->subrev = 0;
    while (isdigit(*tag))
        p->subrev = p->subrev * 10 + *tag++ - '0';
    return *tag == '\n' || *tag == '\0';
}

static void packTags(string_t *buf) {
    int prefixLen = (int)strlen(tagPrefix);
    char *t       = buf->str;
    char *s       = buf->str;
    while (*s) {
        if (isPrefix(s, tagPrefix)) {
            s += prefixLen;
            while (*s && *s != '\n')
                *t++ = *s++;
            *t++ = '\n';
        }
        s = (s = strchr(s, '\n')) ? s + 1 : "";
    }
    *t++     = '\0';
    buf->pos = (int)(t - buf->str + 1);
}

// version has already been setup with the first 3 components in initDates
// the last component has the format
// rev qualifier subqualifer
// where rev and subqualifier are numeric and qualifer is letters or '_'
// all can be null strings
static void generateVersion() {
    tag_t newTag;
    uint16_t maxRev    = 0;
    uint16_t maxSubRev = 0;
    string_t buf       = { 0 };

    int result;
    if (!parseRevision(revision, &newTag))
        fatal("Invalid user specified revision %s", revision);
    if (result = execute(branchCmd, &buf, false) != 0) {
        if (result < 0)
            fatal("Cannot run git");
        else
            fatal("%s is not in a git repository", appName);
    }

    if (buf.pos == 0)
        fatal("Cannot perform a release with detached files");
    if (newTag.qualifier[0] == '\0' && strcmp(buf.str, "master\n") != 0 &&
        strcmp(buf.str, "main\n") != 0) {
        strcpy(newTag.qualifier, "dev");
        debugPrint("On branch %s but no qualifier. Using 'dev' qualifier", buf.str);
    }

    initString(&buf, 1024);
    if (execute(tagListCmd, &buf, false))
        fatal("Failed to read tags");
    packTags(&buf);
    // scan for tags with no qualifier to determine the latest
    for (char *s = buf.str; *s; s++) {
        tag_t oldTag;
        if (parseRevision(s, &oldTag) && !oldTag.qualifier[0] && oldTag.rev > maxRev)
            maxRev = oldTag.rev;
        if (!(s = strchr(s, '\n')))
            break;
    }
    if (newTag.rev == 0)
        newTag.rev = maxRev + 1;
    if (newTag.qualifier[0]) {
        // scan for maxSubRev
        for (char *s = buf.str; *s; s++) {
            tag_t oldTag;
            if (parseRevision(s, &oldTag) && oldTag.rev == newTag.rev &&
                strcmp(oldTag.qualifier, newTag.qualifier) == 0 && oldTag.subrev > maxSubRev)
                maxSubRev = oldTag.subrev;

            if (!(s = strchr(s, '\n')))
                break;
        }
        if (newTag.subrev == 0)
            newTag.subrev = maxSubRev + 1;
    }

    if (newTag.qualifier[0] == '\0' ? newTag.rev < maxRev : newTag.subrev < maxSubRev)
        fatal("Backwards revisions are not allowed");
    char revision[64];
    sprintf(revision, "%d", newTag.rev);
    strcat(version, revision);
    strcat(tagPrefix, revision);
    if (newTag.qualifier[0]) {
        sprintf(revision, "-%s%d", newTag.qualifier, newTag.subrev);
        strcat(version, revision);
        strcat(tagPrefix, revision + 1);
    }
    if (newTag.qualifier[0] == '\0' ? newTag.rev == maxRev : newTag.subrev == maxSubRev) {
        if (execute(tagDate, &buf, false) != 0 ||
            strtoull(buf.str, NULL, 10) / 86400 != timeNow / 86400)
            fatal("Re-release only supported for same day");  
    }
}

#if 0
static void show(char **p) {
    while (*p)
        printf("'%s' ", *p++);
    putchar('\n');
}
#endif

int main(int argc, char **argv) {
    while (getopt(argc, argv, "dr:m:c:") != EOF) {
        switch (optopt) {
        case 'm':
            message = optarg;
            break;
        case 'r':
            revision = optarg;
            break;
        case 'd':
            debug = true;
            break;
        case 'c':
            configFile = optarg;
            break;
        }
    }

    appName = getAppName();
    sprintf(tagPattern, "%s-r[1-9]*", appName);
    sprintf(tagPrefix, "%s-r", appName);
    initDates();
    for (char **p = addCmd; *p; p++)
        addPathIndex++;
    addCmd[addPathIndex] = versionFile = parseConfig(configFile);

    generateVersion();

    char *saveFile = tmpnam(NULL);
    if (!saveFile)
        saveFile = "_oldVersion_";
    //   sprintf(saveFile, "_v_%d", getpid());
    int rstatus = rename(versionFile, saveFile);

    writeNewVersion(versionFile, version, date);
    string_t msg = { 0 };
    if (execute(addCmd, NULL, false) == 0) {
        char const **command;

        if (execute(diffIndexCmd, NULL, false) == 0)
            command = commitAmendCmd;
        else {
            sprintf(messageStr, "\"%s - %s: %s\"", appName, version, message);
            command = *message ? commitCmd : commitEditCmd;
        }
        if (execute(command, NULL, true) == 0) {
            sprintf(messageStr, "\"Release %s - %s\"", appName, version);
            if (execute(tagCmd, NULL, false) != 0)
                warn("Tag creation failed please fix manually");
            if (rstatus == 0)
                unlink(saveFile);
            return 0;
        }
    }
    if (msg.str)
        fputs(msg.str, stderr);
    unlink(versionFile);
    if (rstatus == 0)
        (void)rename(saveFile, versionFile);
}
