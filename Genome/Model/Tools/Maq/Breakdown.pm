package Genome::Model::Tools::Maq::Breakdown;

use strict;
use warnings;

use Genome;

my @TAGS = qw/TRANSCRIPT RIBOSOME CHEMISTRY/;

class Genome::Model::Tools::Maq::Breakdown {
    is => ['Genome::Model::Tools::Maq','Genome::Utility::FileSystem'],
    has => [
            map_file => { is => 'Text',},
            tags => { is => 'List', default_value => \@TAGS },
            use_version => {default_value => '0.7.1'},
        ],
};

sub execute {
    my $self = shift;

    my $map_file = $self->map_file;

    unless ($self->validate_file_for_reading($map_file)) {
        $self->error_message("Failed to validate map file '$map_file' for reading:  $!");
        die $self->error_message;
    }

    my $basename = File::Basename::basename($self->map_file);
    my $tmp_file = $self->create_temp_file_path($basename .'.mapview');
    if (-e $tmp_file) {
        unlink($tmp_file) || die 'Failed to remove tmp file '. $tmp_file .":  $!";
    }
    require POSIX;
    POSIX::mkfifo($tmp_file,0700) || die "Failed to make named pipe '$tmp_file':  $!";
    my $version = $self->use_version;
    my $cmd = $self->maq_path ." mapview $map_file > $tmp_file &";
    $self->shellcmd(
                    cmd => $cmd,
                    input_files => [$map_file],
                    #output_files => [$tmp_file],
                );
    my $mapview_fh = IO::File->new($tmp_file,'r');
    unless ($mapview_fh) {
        $self->error_message("Failed to open named pipe tmp mapview output '$tmp_file':  $!");
        die $self->error_message;
    }
    my %subject_count;
    my %seq_count;
    my $total;
    while (my $line = $mapview_fh->getline) {
        chomp($line);
        my @entry = split("\t", $line);
        my $subject = $entry[1];
        my $seq = $entry[14];
        my $found;
        for my $tag (@{$self->tags}) {
            if ($subject =~ /^$tag/) {
                $subject_count{$tag}++;
                $found = 1;
            }
        }
        unless($found) {
            $subject_count{UNKNOWN}++;
        }
        my $polyA;
        my $polyT;
        if ($seq =~ /A{10,}/i) {
            $seq_count{polyA}++;
            $polyA = 1;
        } elsif ( $seq =~ /T{10,}/i) {
            $seq_count{polyT}++;
            $polyT = 1;
        }
        if ($polyA && $polyT) {
            $seq_count{'polyAT'}++;
        }
        $total++;
    }
    $mapview_fh->close;
    if (-e $tmp_file) {
        unlink($tmp_file) || die "Failed to remove named pipe tmp file '$tmp_file':  $!";
    }
    #TODO: break the printing out into methods
    print "SUBJECT BREAKDOWN:\n";
    for my $subject (sort {$a cmp $b} keys %subject_count) {
        my $value = $subject_count{$subject};
        my $pc = sprintf("%.02f",(($value/$total)*100));
        print $subject ."\t". $value ."\t". $pc."%\n";
    }
    print "SEQUENCE BREAKDOWN:\n";
    for my $seq (sort {$a cmp $b} keys %seq_count) {
        my $value = $seq_count{$seq};
        my $pc = sprintf("%.02f",(($value/$total)*100));
        print $seq ."\t". $value ."\t". $pc ."%\n";
    }
    return 1;
}


1;
