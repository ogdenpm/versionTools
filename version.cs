﻿using System;
/*
 * Display the version info in a standard way
 *
 * in main program put the following code
 * using GitVersionInfo;
 *
 * if (args[0].ToLower() == "-v") {
 *  VersionInfo.showVersion(args[0] == "-V");
 *  return 0;
 * }
 */

namespace GitVersionInfo
{
    public partial class VersionInfo
    {
        public static void showVersion(bool full)
        {
            Console.Write($"{GIT_APPNAME} {GIT_VERSION}");
#if DEBUG
                Console.Write(" {debug}");
#endif
            Console.WriteLine($"  (C){GIT_YEAR} Mark Ogden");
            if (full)
            {
                Console.Write($"Git: {GIT_SHA1} [{GIT_CTIME.Substring(0, 10)}]");
#pragma warning disable CS0162
                if (GIT_BUILDTYPE == 2)
                    Console.WriteLine($" +uncommitted files");
                else if (GIT_BUILDTYPE == 3)
                    Console.WriteLine($" +untracked files");
                else
                    Console.WriteLine("");
#pragma warning restore CS0162
            }
        }
    }
}
