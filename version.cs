
using System;

namespace GitVersionInfo
{
    public partial class VersionInfo
    {
        public static void showVersion(bool full)
        {
            #if DEBUG
            string debug = " {debug}";
            #else
            string debug = "";
#endif
            Console.WriteLine($"{GIT_APPNAME} - {GIT_VERSION}{debug} (C){GIT_YEAR} Mark Ogden");

            if (full)
            {
                string sha1 = GIT_SHA1 + (GIT_BUILDTYPE == 1 ? "+" : "");
                Console.WriteLine($"Program: {GIT_APPNAME} {sha1} [{GIT_CTIME.Substring(0, 10)}]");
            }
        }
    }
}
