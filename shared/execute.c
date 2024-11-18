#include "support.h"
#include <ctype.h>
#include <fcntl.h>
#include <io.h>
#include <process.h>
#include <stdio.h>

#define PIPELEN 256
enum { PREAD = 0, PWRITE = 1 };

int execute(char const *const *cmd, string_t *str, bool isInteractive) {
    int pipes[2];
    char buf[512];
    int oldStdout;
    int oldStderr;

    if (str) {
        str->pos = 0;       // reset any previous string
        if (_pipe(pipes, PIPELEN, _O_TEXT | O_NOINHERIT) == -1) {
            fprintf(stderr, "pipe failed\n");
            exit(1);
        }
        if (!isInteractive) {
            oldStdout = dup(_fileno(stdout));
            dup2(pipes[PWRITE], _fileno(stdout));
        }
        oldStderr = dup(_fileno(stderr));
        dup2(pipes[PWRITE], _fileno(stderr));
        close(pipes[PWRITE]);
    }
    int result;

    intptr_t pid = _spawnvp(P_NOWAIT, "git.exe", cmd);
    if (str) {
        if (!isInteractive)
            dup2(oldStdout, _fileno(stdout));
        dup2(oldStderr, _fileno(stderr));
    }
    if (pid > 0) {
        if (str) {
            str->pos = 0;
            int actual;
            while ((actual = (int)read(pipes[PREAD], buf, sizeof(buf))))
                appendBuffer(str, buf, actual);
            appendBuffer(str, "", 1);
        }
        _cwait(&result, pid, WAIT_CHILD);
    } else
        result = -1;
    if (str)
        close(pipes[PREAD]);
    return result;
}
