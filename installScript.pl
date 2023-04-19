# to modify
# expand all files to be processed using glob
# for each directory part of the file add to list to be processed
# starting with shortest path
# process status ignoring submodules
#   mark the directory as processed along with any other
#   subdirectory status highlights
# repeat until no outstanding directories to process
#
#
use File::Spec;
use File::Basename;
use Cwd 'realpath';

my $cacheDir;
my $cacheBranch;
my %cacheQualifier;
my %revisions;

my %trees;
my @sortedTree;
my @targets;
my @files;
my %statusMap = ("??" => "*Untracked", "!!" => "*Ignored", "A " => "*Pending");

my $defaultScript = "installScript.cfg";

sub usage {
    print "$_[0]\n\n" if $_[0] ne "";
    print "Usage: ", basename($0), " -v | -h | targetdir file+ | -s scriptFile\n";
    print "Where:\n";
    print "-v             shows version information\n";
    print "-h             shows this help information\n";
    print "targetdir      where to install to. The directory must exist\n";
    print "file+          a space separated list of the files to install\n";
    print "-s scriptFile  takes a list of targetdir and file+ specifications to use\n";
    print "               from the specified script file\n";
    print "if no arguments are given -s $defaultScript is assumed\n";
    exit(0);
}


sub addFile {
    my $target = realpath($_[0]);
    my $file = realpath($_[1]);
    $_[1] =~ s/\\/\//g;
    $file =~ s/\\/\//g;     # normalise to / directory separator
    $file =~ /^(.*\/).*$/;
    $trees{$1} = 1;
    push @targets, $target if $targets[-1] ne $target;
    push @{$files[$#targets]}, $_[1];
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

# get the branch and status
sub getStatus {
    @sortedTree = (sort keys %trees);       # process highest tree first
    my $noneGit;
    while (my $path = shift @sortedTree) {
        next if defined($branch{$path}) && $branch{$path} ne "*Submodule";
        my @submodules;
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
                            $status{$f} = $s;
                        }
                    }
                }
            }
            close $in;
            next if $noneGit; # if dir is not under git, subdirectories may be

            my @submodules;
            while (my $subdir= shift @sortedTree) {
                if (substr($subdir, 0, length($path)) eq $path) {
                    $branch{$subdir} = getSubdirStatus($subdir);
                    if ($branch{$subdir} eq "*Submodule") {
                        push @submodules, $subdir;      # treat submodules as their own trees
                    }
                } else {
                     unshift @sortedTree, $subdir;      # add submodules back
                     last;
                }
             }
             unshift @sortedTree, @submodules;
        } else {
            print "git not installed\n";
            exit(1);
        }
    }
}



sub getRevision {
    
    my $fullpath = realpath($_[0]) . (-d $_[0] ? "/" : "");
    $fullpath =~ s/\\/\//g;         # convert to / usage for later tests;
    return $revisions{$fullpath} if defined($revisions{$fullpath}); # previously detemermined to quick return
    my ($dir, $file) = ($fullpath =~ /^(.*\/)(.*)$/);
    $file ||= ".";
    return $revision{$fullpath} = substr($branch{$dir}, 1) if substr($branch{$dir}, 0, 1) eq "*";
    return $revision{$fullpath} = substr($status{$fullpath}, 1) if substr($status{$fullpath}, 0, 1) eq "*";

    my $sha1, $ctime;
    open my $in, "git -C \"$dir\" log -1 --format=\"%h %ct\" -- $file |" or die $!;
    ($sha1, $ctime) = (<$in> =~ /(\S+)\s+(\S+)/);
    close $in;

    return $revisions{$fullpath} = sprintf "%s%s.g%s%s",  $branch{$dir}, gmt2Ver($ctime), $sha1, $status{$fullpath} ne "" ? "+" : "";
}

sub install {
    getStatus();    # get all of the relevant status info

    for (my $i = 0; $i < @targets; $i++) {
        my $dir = $targets[$i];
        print "Installing to $dir\n";
        for my $file (@{$files[$i]}) {
            my $revision = getRevision($file);
            my $name = $file;
            $name =~ s/.*[\/\\]//;
            my $target = File::Spec->catfile(realpath($dir), $name);

            if (realpath($file) eq $target) {
                print "$file - skipping attempt to overwrite source file\n";
                return;
            }
            my $content;

            open my $in, "<", $file or die $!; {
                local $/;
                $content = <$in>;
            }
            close $in;
            my $pattern = "_" . "REVISION" . "_";    # to avoid matching in this file
            $content =~ s/$pattern/$revision/g;
            open $out, ">", $target or die $!;
            print $out $content;
            close $out;
            printf "  %-20s %s\n", "$file:", $revision;
        }
    }
}

sub useScript {
    my $script = $_[0];
    if (! -f $script) {
        print "script file $script does not exist\n";
        return;
    }
    open my $in, "<", $script or usage("can't read $script");
    my $flist, $file, $dir;

    while (<$in>) {
        next if /^#/ || /^\s*$/;
        chomp;
        if (/^"(.*)"(.*)/ || /^(\S+)(.*)/) {
            $dir = $1;
            $flist = $2;
            if (-d $dir) {
                while ($flist =~ /^\s*"([^"]*)"(.*)/ || $flist =~ /^\s*(\S+)(.*)/) {
                    $file = $1;
                    $flist = $2;
                    if (-f $file) {
                        addFile($dir, $file);
                    } else {
                        print "file '$file' not found, skipping\n";
                    }
                }
            } else {
                print "directory '$dir' not found, skipping installs\n";
            }
        }
    }
    close $in;
    install();
}

main:
if ($#ARGV == 0) {
    if ($ARGV[0] eq "-v") {
        print basename($0), ": _REVISION_\n";
    } else {
        usage();
    }
} else {
    my $opt = shift(@ARGV);
    if ($opt eq "-s") {
        useScript($ARGV[0]);
    } elsif ($opt eq "") {
        useScript($defaultScript);
    } elsif  (-d $opt) {
        # convert filenames to full path and find the parent directory
        while ((my $file = shift(@ARGV)) ne "") {
            if (-f $file) {
                addFile($opt, $file);
            } else {
                print "file '$file' not found, skipping\n";
            }
        }
        install();
    } else {
       usage("directory '$opt' not found");
    }
}

