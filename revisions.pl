#! /usr/bin/perl 
# this is perl port of revisions.cmd + filever.cmd
use File::Spec;
use File::Basename;

use Cwd 'realpath';

# Used simplified version of version.cmd to show the revisions to a specific file
# since creation.
# Limitation is that it has limited accuracy on tracking moves or and does not support renames (except case change)
my $quiet;

my $cacheDir;
my $cacheBranch;
my %cacheQualifier;



sub usage {
    my $invokeName = basename($0);
    print <<EOF;
usage: $invokeName [-v] | [-q] [file | dir]*
where -v shows version info
      -q supresses no Git info for file message
if no file or dir specified - defaults to .
EOF
    exit(0);
}

sub unix2GMT {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    return sprintf"%04d-%02d-%02d", 1900 + $year, $mon + 1, $mday;

}

sub showRevision {
    my $path = $_[0];
    my $GIT_BRANCH;
    my $GIT_QUALIFIER = " ";
    my $fullpath = realpath($path);
    $fullpath =~ s/\\/\//g;         #convert to / usage for later tests;
    my ($volume, $directories,$file) = File::Spec->splitpath(($fullpath));

# check for banch and any outstanding commits
    if ($cacheDir ne $directories) {
        if (open my $in, "git status -s -b -uno -- \"$directories\" 2>" . File::Spec->devnull() . " |") {
            $cacheDir = $directories;
            %cacheQualifer = ();
            $cacheBranch = "";
            while (<$in>) {
                if (/^## (\w+)/) {
                    $cacheBranch = $1;
                } else {
                    /^(..)\s*(\S*)/;
                    $cacheQualifier{$2} = '+' if $1 ne "  ";
                }
            }
            close $in;
        } else {
            print "git not installed\n";
            exit(1);
        }
    } 
    if ($cacheBranch eq "") {
        print "$file outside of Git repository\n" unless $quiet;
        return;
    }

    $GIT_BRANCH = $cacheBranch;
    $GIT_QUALIFIER = $cacheQualifier{$file};

    my $scope = $file;            # look for all files with this name

    open my $in, "git ls-files --full-name HEAD -- \":(icase,top)*$scope\" |";
    @match = <$in>;
    close $in;
    if (@match > 1) {           # if there are many, look for longest unique tail path
        chomp @match;
        my @dirs = File::Spec->splitdir($directories);
        pop @dirs;              # waste the blank dir entry
        while (@match > 1) {    # loop until tail path is unique
            $scope = (pop @dirs) . "/$scope";
            @match = grep(index($_, $scope) >= 0, @match);
        }
    }
    if (@match == 0 || index($fullpath, $scope) < 0) {
        print "$file is currently untracked\n" unless $quiet;
        return;
    }
    # get the log entries for all files matching the scope
    open my $in, "git log HEAD --format=\"%h %ct\"-- \":(icase,top)*$scope\"|";
    my @commits = <$in>;
    close $in;
    my $GIT_COMMITS = @commits;
    my ($GIT_SHA1, $UNIX_CTIME) = ($commits[0] =~ /(\S+)\s+(\S+)/);
  
    printf "%-20s Rev: %2d%s", $path, $GIT_COMMITS, $GIT_QUALIFIER;
    if ($GIT_BRANCH ne "master" && $GIT_BRANCH ne "main") {
        print " {$GIT_BRANCH}";
    }
    print " -- git $GIT_SHA1 [" . unix2GMT($UNIX_CTIME) . "]\n";
}

sub showDirRevisions {
    my $home = File::Spec->curdir();
    if ($_[0] ne ".") {
        print "Revisions for $_[0]\n";
        chdir $_[0];
    }
    if (opendir(my $dir, ".")) {
        while (my $f = readdir($dir)) {
            if (-f $f) {
                showRevision($f);
            }
        }
        closedir($dir);
    }
    chdir $home;
}



main:   # main code
if (lc($ARGV[0]) eq "-v") {
    print basename($0), ": Rev _REVISION_\n";
    exit(0);
}
if ($ARGV[0] eq "-q") {
    $quiet = 1;
    shift @ARGV;
}
usage() if substr($ARGV[0], 0, 1) eq '-';

if (@ARGV[0] eq "") {
    showDirRevisions(".");
} else {
    while ((my $w = shift @ARGV) ne "") {
        for my $a (glob($w)) {
            if (-f $a) {
                showRevision($a);
            } elsif (-d $a) {
                showDirRevisions($a);
            } else {
                print "$a not a file or directory\n";
                usage();
            }
        }
    }
}


