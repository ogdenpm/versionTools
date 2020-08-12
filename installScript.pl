use File::Spec;
use File::Basename;
use Cwd 'realpath';


sub unix2GMT {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($_[0]);
    return sprintf"%04d-%02d-%02d %02d:%02d:%02d", 1900 + $year, $mon + 1, $mday, $hour, $min, $sec;

}


sub getRevision {
    my $file = @_[0];
    my $branch, $sha1, $revision, $uCTime, $cTime;
# Check branch and outstanding commits
    if (open $in, "git status -s -b -uno -- :(icase)$file |") {
        while (<$in>) {
            if (/^## (\w+)/) {
                $branch = $1;
            } elsif (substr($_, 0, 2) ne "  ") {
                $qualifier = "+$qualifier";
                 last;
            }
        }
        close $in;
    }
    $qualifier .= "-$branch" unless $branch eq 'master';

    # get the relevant SHA1 and commit time
    open $in, "git log -a --format=\"%h %ct\" -- :(icase)$file |" or die $!;
    ($sha1, $uCTime) = (<$in> =~ /(\S+)\s+(\S+)/);
    close $in;
    die "Cannot find information for " . basename($file) . "\n" if $sha1 eq "";
    $cTime = unix2GMT($uCTime);

    # get the commits in play
    open my $in, "git rev-list --count HEAD -- :(icase)$file |" or die $!;
    ($revision) = (<$in> =~ /(\d+)/);
    close $in;
    return "$revision$qualifier -- git $sha1 [" . substr($cTime, 0, 10) . "]";
}

main:
if ($#ARGV == 0 && $ARGV[0] eq "-v") {
    print basename($0), ": Rev _REVISION_\n";
} elsif ($#ARGV != 1 || !-f $ARGV[0] || !-d $ARGV[1]) {
    print "Usage: ", basename($0), " -v | file targetDir\nWhere file and targetDir must exist\n";
} else {
    my $file =$ARGV[0];
    my $dir = $ARGV[1];
    my $target = File::Spec->catfile(realpath($dir), $file);
    my $content;
    my $revision = getRevision($file);
    if (realpath($file) eq $target) {
        print "Error: Source and Destination are the same file\n";
        exit(1);
    }
    open $in, "<", $file or die $!; {
        local $/;
        $content = <$in>;
    }
    close $in;
    my $pattern = "_" . "REVISION" . "_";    # to avoid matching in this file
    $content =~ s/$pattern/$revision/g;
    open $out, ">", $target or die $!;
    print $out $content;
    close $out;
    print "installed '$file' Rev: $revision\n";
}

