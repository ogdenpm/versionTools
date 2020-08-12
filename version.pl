#! /usr/bin/perl 
# this is perl port of version.cmd
use File::Path qw(make_path);
use File::Basename;
use File::Copy;
use Cwd qw(getcwd);

$DEFAULTS_FILE = 'version.in';
my %defaults;
my $GIT_APPID;
my $GIT_APPDIR;


sub safePath {
    return 1 if $_[0] eq "" || -d $_[0]; 
    make_path($_[0], {error => \my $err} );
    if ($err && @$err) {
        for my $diag (@$err) {
            my ($file, $message) = %$diag;
            if ($file eq '') {
                print "general error: $message\n";
            }
            else {
                print "problem making directory $file: $message\n";
            }
        }
        print "\n";
        return 0;
    }
    return 1;
}

# getOpts, return 1 if ok to proceeed
sub getOpts {
    return 0 if $ARGV[0] eq '-h';

    while (my $opt = shift @ARGV) {
        if (substr($opt, 0, 1) eq '-') {
            if ($opt eq '-q') {
                $fQUIET = 1;
            } elsif ($opt eq '-f') {
                $fFORCE = 1;
            } elsif ($opt eq '-a') {
                $GIT_APPID = shift @ARGV;
                return 0 if $GIT_APPID eq "";
            } else {
                return 0;
            }
         } else {
            $CACHE_DIR = $opt;
            $CACHE_DIR =~ s/[\\\/]$//;      # remove any training dir separator
            return 0 unless ($HEADER_FILE = shift @ARGV);
            return 0 if shift @ARGV;
            $CACHE_DIR = '.' if $CACHE_DIR eq "";
            $CACHE_FILE = "$CACHE_DIR/GIT_VERSION_INFO";
            return safePath($CACHE_DIR) && safePath(dirname($HEADER_FILE));
         }
    }
    return $fQUIET != 1;
}

sub usage {
    my $invokeName = basename($0);
    print <<EOF;
usage: $invokeName [-h] ^| [-q] [-f] [-a appid] [CACHE_PATH OUT_FILE]

 When called without arguments version information writes to console

 -h          - displays this output

 -q          - Suppress console output
 -f          - Ignore cached version information
 -a appid    - set appid. An appid of . is replaced by parent directory name
 CACHE_PATH  - Path for non-tracked file to store git version info used
 OUT_FILE    - Path to writable file where the generated information is saved
EOF
}

sub loadDefaults {
    if (open my $in, "<$DEFAULTS_FILE") {
        while (<$in>) {
            chomp;
            s/\s*$//;       # remove trailing spaces
            $defaults{$1} = $2 if /#define\s*(\w+)\s*"?([^"]*)/;
        }
    }
    close $in;
    $GIT_APPDIR = basename(getcwd);
    if ($GIT_APPID eq "") {
        $GIT_APPID=$defaults{GIT_APPID};
    } elsif ($GIT_APPID eq '.') {
        $GIT_APPID = $APPDIR;
    }
}

sub unix2GMT {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    return sprintf"%04d-%02d-%02d %02d:%02d:%02d", 1900 + $year, $mon + 1, $mday, $hour, $min, $sec;

}

sub getVersionString {
    $GIT_BUILDTYPE = 0;
# check for banch and any outstanding commits in current tree
    if (open my $in, "git status -s -b -uno -- . |") {
        while (<$in>) {
            if (/^## (\w+)/) {
                $GIT_BRANCH = $1;
                $GIT_BUILDTYPE = 1 if $GIT_BANCH ne 'master';
            } elsif (substr($_, 0, 2) ne "  ") {
                $GIT_QUALIFIER = ".P";
                $GIT_BUILDTYPE = 2;
                last;
            }
        }
        close $in;
    }
    return unless defined $GIT_BRANCH;
    $GIT_QUALIFIER .= "-$GIT_BRANCH" if $GIT_BRANCH ne "master";
    # get the current SHA1 and commit time for the items in the directory
    open my $in, 'git log -1 --format="%h %ct" -- . |' or die $!;
    ($GIT_SHA1, $UNIX_CTIME) = (<$in> =~ /(\S+)\s+(\S+)/);
    close $in;
    $GIT_CTIME = unix2GMT($UNIX_CTIME);

    $prefix = "$GIT_APPID-" if $GIT_APPID ne "";
    # Use git tag to get the lastest tag applicable to the contents of this directory
    open my $in, "git tag -l $prefix[0-9]*.*[0-9] --sort=-v:refname --merged $GIT_SHA1 |" or die $!;
    $strTAG = <$in>;
    chomp $strTAG;
    close $in;

    my $scope= ($strTAG ne ""  ? "$strTAG.." : "") . "HEAD";
    # get the commits in play
    # two options for calculating commits
    open my $in, "git rev-list --count $scope -- . |" or die $!;
    $GIT_COMMITS = <$in>;
    chomp $GIT_COMMITS;
    close $in;

    $strTAG =~ s/.*-//;     # remove appid prefix
    $strTAG = "0.0" if $strTAG eq "";
    $GIT_VERSION_RC = "$strTAG,$GIT_COMMITS,$GIT_BUILDTYPE";
    $GIT_VERSION_RC =~ s/\./,/;
    $GIT_VERSION="$strTAG.$GIT_COMMITS$GIT_QUALIFIER";
}

sub checkCache {
    if (-f $HEADER_FILE && -f $CACHE_FILE && open my $in, "<", $CACHE_FILE) {
        my $oldVer = <$in>;
        close $in;
        chomp $oldVer;
        if ($oldVer eq "$GIT_APPID-$GIT_VERSION-$GIT_SHA1") {
            print "Build version is assumed unchanged from $GIT_VERSION\n" unless $fQuiet;
            return 1;
        }
    }
    open my $out, ">", $CACHE_FILE or die $!;
    print $out "$GIT_APPID-$GIT_VERSION-$GIT_SHA1\n";
    close $out;
    return 0;
}

sub writeOut {
    if (defined($HEADER_OUT_FILE)) {
        open my $out, ">", $HEADER_OUT_FILE or die $!;
        print $out "// Autogenerated version file\n";
        my $guard = "v$GIT_VERSION_RC";
        $guard =~ s/,/_/g;
        print $out "#ifndef $guard\n#define $guard\n";
        print $out "#define GIT_APPID       \"$GIT_APPID\"\n" if $GIT_APPID ne ""; 
        print $out "#define GIT_VERSION     \"$GIT_VERSION\"\n";  
        print $out "#define GIT_VERSION_RC  $GIT_VERSION_RC\n";
        print $out "#define GIT_SHA1        \"GIT_SHA1\"\n";   
        print $out "#define GIT_APPDIR      \"GIT_APPDIR\"\n";   
        print $out "#define GIT_CTIME       \"GIT_CTIME\"\n";
        print $out "#define GIT_YEAR        \"", substr($GIT_CTIME, 0, 4), "\"\n";
        print $out "#endif\n";
        close $out;
    }
    if (!defined($fQUIET)) {
        print "Git App Id:           $GIT_APPID\n";
        print "Git Version:          $GIT_VERSION\n";
        print "Build type:           $GIT_BUILDTYPE\n";
        print "SHA1:                 $GIT_SHA1\n";
        print "App Dir:              $GIT_APPDIR\n";
        print "Committed:            $GIT_CTIME\n";
    }
}


main:   # main code
if (lc($ARGV[0]) eq "-v") {
    print basename($0), ": Rev _REVISION_\n";
    exit(0);
}
if (!getOpts()) {
    usage();
} else {
    loadDefaults();
    getVersionString();
    if ($GIT_SHA1 eq "") {
        if ($defaults{GIT_SHA1} eq "") {
            print "No Git information and no $DEFAULTS_FILE file\n";
            exit(1);
        }
        copy($DEFAULTS_FILE, $HEADER_OUT_FILE) if defined($HEADER_OUT_FILE);
            
        $GIT_SHA1 = "untracked";
        $GIT_VERSION = $defaults{GIT_VERSION};
        $GIT_BUILDTYPE = 3;
        $GIT_BRANCH = $defaults{GIT_BRANCH};
        $GIT_CTIME = $defaults{GIT_CTIME};
   } 
    writeOut if $CACHE_FILE eq "" || !checkCache();
}

