#! /usr/bin/perl 
# this is perl port of gitver.cmd
#  Script for generation of version info suitable for windows VERSION_INFO and application use
#  This is a much simplified version that takes the latest commit for files in a given directory
#  If a version file is being generated then the following #defines is included
#  #define GIT_VERSION "[branch-]yyyy.mm.dd.(release | gsha1)[+][?]"
#     yyyy.mm.dd  is the date in UTC of the last commit, leading zeros omitted
#     release     is the numeric component of the release tag if the commit has a tag associated
#     gsha1       is the start of the git SHA1 preceeded by a g
#     +           added if uncommitted files
#     ?           added if no git, the question mark represents untracked
#     branch      present if not non main or master. A detached branch is shown as (detached)
# if git information cannot be found and an output file is specified then
#     if the output file already exists the existing version is used with a ? appended unless it has one already
#     else #define GIT_VERSION "xxxx.xx.xx.xx ?" is written to the file
#
#  Unless surpressed by the -q flag, the generated version is shown on the console
#  -w writes to the VER_FILE currently gitVer.h
#
#  Note when commits are made, without using the gitrel command then the commited gitVer.h
#  will contain the most recent version prior to the commit. If copied to an environment
#  without git installed this version will not be auto corrected, although a ? will be appended
#  It is recommended for sharing the gitrel command is used. This will generate a tag of the form
#  rnnn, with the gitVer.h set appropriately.
#  In the repo, the generated tags are of the form dirname-rnnn, where dirname is the directory
#  containing the relevant files and nnn is a decimal number without leading zeros.
use Cwd;
use POSIX 'ctime';
use File::Basename;
my $VER_FILE;
my $fQUIET;
my $WMODE = 0;  # 0 - no write, 1 - write if changed, 2 - always write
my $TEMPLATE;
my $OLD_GIT_VERSION;

my $DEF_VER_FILE="_version.h";

my $cwd = cwd();
$cwd =~ s/.*\///;   # parent directory name

sub usage {
    my $invokeName = basename($0);
    print <<EOF;
usage: $invokeName -v | [-h] | [-q] [-w|-W] [-t template] file

 When called without arguments version information writes to console

 -v          - displays script version information
 -h          - displays this usage information

 -q          - Suppress console output, ignored if not writing to file
 -w          - write header file if version changed
 -t template - template file to be used to write file
 -W          - write header file even if version unchanged
 file        - header file to write defaults to $DEF_VER_FILE
EOF
}


# getOpts, return 1 if ok to proceeed
sub getOpts {
    while (my $opt = shift @ARGV) {
        if (lc($opt) eq "-v") {    
            print basename($0), ": Ver _REVISION_\n";
            exit(0);
        }
        if (lc($opt) eq "-q") {
            $fQUIET = 1;
        } elsif ($opt eq "-w" && $WMODE == 0) {
            $WMODE = 1;
        } elsif ($opt eq "-W" && $WMODE == 0) {
            $WMODE = 2;
        } elsif (lc($opt) eq "-t" && $TEMPLATE eq "" && $#ARGV >= 0 && -f $ARGV[0]) {
            $TEMPLATE = shift @ARGV;
        } elsif (substr($opt,0,1) eq "-" || $#ARGV >= 0) {
            usage();
            exit(0);
        } else {
            $VER_FILE = $opt;
        }
    }
    $VER_FILE = $DEF_VER_FILE if $VER_FILE eq "";
    $fQUIET = 0 if $WMODE == 0;
} 



sub time2Ver {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    $year += 1900;
    $mon++;
    return "$year.$mon.$mday";

}

sub getOldVersion {
   if (-f $VER_FILE && open my $fh, "<", $VER_FILE) {
        while (<$fh>) {
            $OLD_GIT_VERSION = (split /['"]/)[1] if /GIT_VERSION/;
        } 
        close $fh;
   }
   $OLD_GIT_VERSION="xxxx.xx.xx.xx?" if $OLD_GIT_VERSION eq "";
}

sub getVersionId {
# check for banch and any outstanding commits in current tree
    if (open my $in, "git status -s -b -uno -- . 2>&1 |") {
        while (<$in>) {
            last if /^fatal/;
            if (/^## (\w+)/) {
                $GIT_BRANCH = $1 ne "HEAD" ? $1 : "(detached)";
            } elsif (! /^...$VER_FILE$/) {
                $GIT_QUALIFIER = "+";
                last;
            }
        }
        close $in;
    }
    return unless defined $GIT_BRANCH;
    # get the current SHA1 and commit time and any tag for the current directory
    open my $in, "git log -1 --decorate-refs=\"tags/$cwd-r*\" --format=\"%h,%ct,%D\" -- . |" or die $!;
    ($GIT_SHA1, $GIT_CTIME, $TAG) = split /,/,<$in>, 3;
    close $in;
    if ($TAG =~ /-r(\d+)(\r)?$/) {   # if tag use it
        $GIT_SHA1 = $1;
    } else {
        $GIT_SHA1 = "g$GIT_SHA1";   # else use SHA1 prefixed with 'g'
    }
}

sub getVersionString {
    $GIT_VERSION = time2Ver($GIT_CTIME);

    $GIT_VERSION .= ".$GIT_SHA1$GIT_QUALIFIER";

    if ($GIT_BRANCH ne "master" && $GIT_BRANCH ne "main") {
        $GIT_VERSION = "$GIT_BRANCH-$GIT_VERSION";
    } 
}

sub writeOut {
    return if $WMODE == 1 && $OLD_GIT_VERSION eq $GIT_VERSION;
    open my $out, ">$VER_FILE" or die "can't write $VER_FILE";
    if ($TEMPLATE ne "") {
        open my $tmpl, "<", $TEMPLATE or die "can't read $TEMPLATE";
        while (<$tmpl>) {
            s/\@\@/$GIT_VERSION/g;
            print $out $_;
        }
        close $tmpl;
    } elsif ($VER_FILE =~ /\.h$/i) {
        print $out "// Autogenerated version file\n";
        print $out "#define GIT_VERSION     \"$GIT_VERSION\"\n";  
    } else {
        print $out "GIT_VERSION \"$GIT_VERSION\"\n";  
    }
    close $out;
}


main:   # main code
getOpts();
getOldVersion();
getVersionId();
if ($GIT_SHA1 ne "") {
    getVersionString();
} else {
    print "No Git information found\n";
    $GIT_VERSION = $OLD_GIT_VERSION;
    $GIT_VERSION .= "?" unless substr($GIT_VERSION, -1) eq "?";
}

writeOut() if $WMODE != 0;
print "$cwd $GIT_VERSION\n" if  !$fQUIET;

