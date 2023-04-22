#! /usr/bin/perl 
# display file/directory revisions
use File::Spec;
use File::Basename;
use Cwd 'realpath';

%statusMap = ("??" => "*Untracked", "!!" => "*Ignored", "A " => "*Pending");


my %status;
my @items;
my %trees;
my $untracked;
my $ignored;
my $noexpand;
my $appmode;
my %revisions;

sub usage {
    my $invokeName = basename($0);
    print <<EOF;
usage: $invokeName -v | -h | [-a|-i|-u|-n]* [--] [file | dir]*
where -v shows version info
      -h show usage and exit
      -a assume directories contain apps
      -n no expansion of directory
      -i include ignored files  
      -u include untracked files
      -- forces end of option processing, to allow file with - prefix
if no file or dir specified then the default is .
file or dir can contain wildcard characters but hidden directories are excluded
EOF
    exit(0);
}

sub gmt2Ver {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    return sprintf"%04d.%d.%d", 1900 + $year, $mon + 1, $mday;

}

# walk up the tree to find the applicable status
# pre check that the directory is in a tree has already been done
sub getSubdirStatus {
    my $sd = $_[0];
    while (!defined($branch{$sd})) {
       $sd =~ s/[^\/]*\/$//;
    }
    return $branch{$sd}; 
}

sub isVersionFile {
    $_[0] =~ /^(.*\/)(.*)$/;
    my ($dir, $file) = ($1, $2);
    if (!defined($vfile{$dir})) {
        my $vf;
        if (open my $in, "<", "${dir}version.in") {
            $vf = $1 if <$in> =~ /^\[([^\]]*)\]/;
            close $in;
        }
        $vfile{$dir} = $vf || "_version.h";        
    }
    return $file eq $vfile{$dir};
}


sub propagateMod {
    my ($root, $item) = @_;
    return if ($appmode && isVersionFile($item));
    $item .= "/";
    do {
        $item =~ s/[^\/]*\/$//;
        if (!defined($status{$item}) || $status{$item} eq "*Submodule") {
            $status{$item} .= "+";
        } else {
            return;
        }
    } while $item ne $root;
}

# get the branch and status
sub getStatus {
    @sortedTree = (sort keys %trees);       # process highest tree first
    my $noneGit;
    while (my $path = shift @sortedTree) {
        next if defined($branch{$path});
        $noneGit = 0;
        if (open my $in, "git -C \"$path\" status -s -b  --ignored -- . 2>&1  |") {
            while (<$in>) {
                if (/^fatal/) {
                    $branch{$path} = "*Untracked";
                    $noneGit = 1;
                    last;
                } else {
                    chomp;
                    if (/^## HEAD \(no branch\)/) {
                        $branch{$path} = "(detached)-";
                    } elsif (/^## (\w+)/) {
                        $branch{$path} = $1 eq "master" || $1 eq "main" ? "" : "$1-";
                    } elsif (/^(..)\s*"([^"]*)"/ || /(..)\s*(\S*)/) {
                        my $s = $statusMap{$1} || "+";
                        my $f = $2 eq "./" ? $path : "$path$2";
                        if (-d $f) {
                            if ($s eq "+") {
                                $branch{"$f/"} = "*Submodule";
                            } else {
                                $branch{$f} = $s; 
                            }
                        } else {
                            if (!$appmode || !isVersionFile($f)) {
                                $status{$f} = $s;
                                propagateMod($path, $f) if $s eq "+" || $s eq "*Pending";
                            }
                        }
                    }
                }
            }
            close $in;
            next if $noneGit; # if dir is not under git, subdirectories may be

            while (my $subdir= shift @sortedTree) {
                if (substr($subdir, 0, length($path)) eq $path) {
                    $branch{$subdir} = getSubdirStatus($subdir);
                } else {
                     unshift @sortedTree, $subdir;      # separate tree
                     last;
                }
             }
        } else {
            print "git not installed\n";
            exit(1);
        }
    }
}

# return Revision number for a file / directory
# the revision number is one of formats listed below
# with yyyy being the commit year, mm the commit month, dd the commid day, rr the commit tag value
# cc is the number of commits for the file/directory. Note numbers have leading 0s surpressed
# sha1 is the commit sha1
# optional + indicates modified uncommitted file
# Untracked             - file/directory not in Git
# Ignored               - file/directory not in Git but explicitly ignored
# Pending               - file not yet in Git but added to staging area
# Submodule             - file is in a submoudle, if detected as such
# if -a and directory
# yyyy.mm.dd.rr+        - directory with an associated tag
# yyyy.mm.dd.sha1+      - directory has no associated tag, sha1 is the base commit
# else
# yyyy.mm.dd.cc+ [sha1] - sha1 is the base commit sha1
#
sub getRevision {
    
    my $fullpath = realpath($_[0]) . (-d $_[0] ? "/" : "");
    $fullpath =~ s/\\/\//g;         # convert to / usage for later tests;
    return $revisions{$fullpath} if defined($revisions{$fullpath}); # previously detemermined so quick return
    my ($dir, $file) = ($fullpath =~ /^(.*\/)(.*)$/);
    $file ||= ".";
    $branch{$dir} = getSubdirStatus($dir) if !defined($branch{$dir});
    return $revision{$fullpath} = substr($branch{$dir}, 1) if substr($branch{$dir}, 0, 1) eq "*";
    return $revision{$fullpath} = substr($status{$fullpath}, 1) if substr($status{$fullpath}, 0, 1) eq "*";

    $fullpath =~ /\/([^\/]*)\/$/;
    my $prefix = $1;
    open my $in, "git -C \"$dir\" log --follow -M100% --first-parent --decorate-refs=\"tags/$prefix-r*\" --format=\"%h,%ct,%D\" -- $file |" or die $!;
    my @commits = <$in>;
    close $in;
    my ($sha1, $ctime, $tag) = split /,/,$commits[0];
    return $revisions{$fullpath} = "Untracked" if $#commits < 0;    # catch empty directory
    if (-d $fullpath && $appmode) {
        $sha1 = $1 if $tag =~ /-r(\w+)\r?$/;
        return $revisions{$fullpath} = $branch{$dir} . gmt2Ver($ctime) . ".$sha1$status{$fullpath}";
    } else {
        my $rev = gmt2Ver($ctime) . "." . ($#commits + 1) .  $status{$fullpath};
        return $revisions{$fullpath} = sprintf "%s%-14s [%s]", $branch{$dir}, $rev, $sha1;
    }
}



sub addItem {
    my $item = $_[0];
    $item =~ tr/\\/\//;
    push @items, $item;     # save in user specified request
    $item = realpath($item) . (-d $item ? "/" : "");
    $item =~ tr/\\/\//;
    $item =~ /^(.*\/).*$/;
    $trees{$1} = 1;
}

sub showItems {
    getStatus();
    for my $item (@items) {
        my $irev = getRevision($item);
        next if $irev eq "Untracked" && !$untracked ||  $irev eq "Ignored" && !$ignored;
        if (-d $item && !$noexpand && $irev ne "Submodule") {
            printf "*Directory* %-18s %s\n", $item , $irev;
            if (opendir my $dir, $item) {
                for my $f (sort readdir($dir)) {
                    next if $f eq "." || $f eq ".." || $f eq ".git";
                    my $frev = getRevision("$item/$f");
                    next if $frev eq "Untracked" && !$untracked ||  $frev eq "Ignored" && !$ignored;
                    #                    $frev =~ s/.*-(\d\d\d\d\.)/\1/;
                    printf "- %-28s %s\n", $f . (-d "$item/$f" ? "/" : ""), $frev;
                } 
            } else {
                print "Can't read directory $item\n";
            }
        } else {
            printf "%-30s %s\n", (-d $item ? "$item/" : $item), $irev;
        }
    }
}



main:   # main code

while ($ARGV[0]) {
    my $opt = lc($ARGV[0]);
    if ($opt eq "-v") {
        print basename($0), ": _REVISION_\n";
        exit(0);
    } elsif ($opt eq "-u") {
        $untracked = 1;
    } elsif ($opt eq "--") {
        last;
    } elsif ($opt eq "-i") {
        $ignored = 1;
    } elsif ($opt eq "-a") {
        $appmode = 1;
    } elsif ($opt eq "-n") {
        $noexpand = 1;
    } elsif (substr($opt, 0, 1) eq '-') {
        usage();
    } else {
        last;
    }
    shift @ARGV;
}

$ARGV[0] = '.' if $#ARGV < 0;

while ((my $a = shift @ARGV) ne "") {
    if (-f $a || -d $a) {
        addItem($a);
    } else {
        my @dirs;
        for my $f (sort glob($a)) {
            if (-f $f) {
                addItem($f);
            } elsif (-d $f) {
               push @dirs, $f;
            }
        }
        for my $d (@dirs) {
            addItem($d);
        }
    }
}


showItems();




