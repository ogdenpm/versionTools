use File::Spec;
use File::Basename;
use Cwd 'realpath';

my $cacheDir;
my $cacheBranch;
my %cacheQualifier;
my %revisions;

my $iswin = $ENV{OS} eq "Windows_NT";
my $top = $iswin ? ":(icase,top)" : ":(top)";


sub usage {
    print "Usage: ", basename($0), " -v | [targetdir file+]\n";
    print "Where targetDir and files must exist\n";
    print "installScript.cfg is used when no arguments are given\n";
    exit(0);
}


sub unix2GMT {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    return sprintf"%04d-%02d-%02d", 1900 + $year, $mon + 1, $mday;

}

sub getRevision {
    my $path = $_[0];
    my $GIT_QUALIFIER = " ";
    my $fullpath = realpath($path);
    $fullpath =~ s/\\/\//g;         #convert to / usage for later tests;
    my ($volume, $directories,$file) = File::Spec->splitpath(($fullpath));

    return $revisions{$fullpath} if defined($revisions{$fullpath});

    # check if this file is in the repository
    open my $in, "git ls-files HEAD -- \"$file\" |";
    my @match = <$in>;
    close $in;
    return $revisions{$fullpath} = "untracked" if @match == 0;


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
                    $cacheQualifier{$iswin ? lc($2) : $2} = '+' if $1 ne "  ";
                }
            }
            close $in;
        } else {
            print "git not installed\n";
            exit(1);
        }
    } 
    return $revisions{$fullpath} = "indeterminate" if $cacheBranch eq "";

    $GIT_QUALIFIER = $cacheQualifier{$iswin ? lc($file) : $file};
    $GIT_GUALIFIER .= " {$cacheBranch}" unless $cacheBranch eq "master" || $cacheBranch eq "main";

    my $scope = $file;            # look for all files with this name

    open my $in, "git ls-files --full-name HEAD -- \"$top*/$scope\" |";
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
 
    # get the log entries for all files matching the scope
    open my $in, "git log HEAD --format=\"%h %ct\"-- \"$top*$scope\"|";
    my @commits = <$in>;
    close $in;
    my $GIT_COMMITS = @commits;
    my ($GIT_SHA1, $UNIX_CTIME) = ($commits[0] =~ /(\S+)\s+(\S+)/);
  
    return $revisions{$fullpath} = 
            sprintf("%2d%-2s", $GIT_COMMITS, $GIT_QUALIFIER) . "-- $GIT_SHA1 [" . unix2GMT($UNIX_CTIME) . "]";
}

sub install {
    my($file, $dir) = @_;
    my $revision = getRevision($file);

    my $target = File::Spec->catfile(realpath($dir), $file);

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
    printf "%-20s Rev: %s\n", $file, $revision;
}

sub useScript {
    open my $in, "<installScript.cfg" or usage();
    my $file, $dir;

    while (<$in>) {
        next if /^#/ || /^\s*$/;
        chomp;
        if (/^"(.*)"(.*)/ || /^(\S+)(.*)/) {
            $dir = $1;
            $_ = $2;
            if (!-d $dir) {
                print "'$dir' not found, skipping installs\n";
                $dir = "";
            } else {
                print "Installing to $dir\n";
            }
        }
        if ($dir ne "") {
           while (/"(.*)"(.*)/ || /(\S+)(.*)/) {
                $file = $1;
                $_ = $2;
                if (!-f $file) {
                    print "file '$file' not found, skipping\n";
                } else {
                    install($file, $dir);
                }
            }
        }
    }
    close $in;

}
main:
if ($#ARGV == 0) {
    if ($ARGV[0] eq "-v") {
        print basename($0), ": Rev _REVISION_\n";
    } else {
        usage();
    }
} else {
    my $dir = shift(@ARGV);
    if ($dir eq "") {
        useScript();
    } elsif (!-d $dir) {
       print "directory $dir must exist\n";
       usage();
    } else {
        print "Installing to $dir\n";
        while ((my $file = shift(@ARGV)) ne "") {
            if (!-f $file) {
                print "file $file doesn't exist\n";
            } else {
                install($file, $dir);
            }
        }
    }
}

