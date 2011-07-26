package Genome::Model::Tools::Maq::Breakdown;

use strict;
use warnings;

use Genome;

# TODO: make these class properties/attributes
my @TAGS = qw/TRANSCRIPT RIBOSOME CHEMISTRY/;
my $annotation = {};

class Genome::Model::Tools::Maq::Breakdown {
    is => ['Genome::Model::Tools::Maq','Genome::Sys'],
    has => [
            map_file => { is => 'Text',},
            tags => { is => 'List', default_value => \@TAGS },
            use_version => {default_value => '0.7.1'},
        ],
    has_optional => [
                  _total => { is => 'Number'},
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
    $self->_total(0);
    while (my $line = $mapview_fh->getline) {
        chomp($line);
        my @entry = split("\t", $line);
        my $subject = $entry[1];
        my $seq = $entry[14];
        if (!$subject || !$seq) {
            $self->warning_message('SKIPPED:   ' . $line . "\n");
            next;
        }
        my $found;
        for my $tag (@{$self->tags}) {
            if ($subject =~ /^$tag/) {
                $self->_update_totals( $seq, $tag );
                $found = 1;
            }
        }
        unless($found) {
            $self->_update_totals( $seq, 'UNKNOWN' )
        }
        $self->_total($self->_total + 1);
    }
    $mapview_fh->close;
    if (-e $tmp_file) {
        unlink($tmp_file) || die "Failed to remove named pipe tmp file '$tmp_file':  $!";
    }


    # REPORTING
    print <<FIELDS;
FIELDS:
[0]  category
[1]  # reads in category
[2]  # total reads
[3]  % category reads in total reads
[4]  # polyAT reads in category
[5]  % polyAT reads in category
[6]  # polyA  reads in category
[7]  % polyA  reads in category
[8]  # polyT  reads in category
[9]  % polyT  reads in category
FIELDS
    print '-' x 77 . "\n";
    for my $tag (@{$self->tags}) {
        $self->_print_category_report( $tag );
    }
    $self->_print_category_report( 'UNKNOWN' );
    print '-' x 77 . "\n";
    print 'TOTAL READS: ' . $self->_total . "\n\n";
    return 1;
}



sub _assess_homopolymer_runs {
    my $self = shift;
    # Loose definition is a run of 10 or more A's or T's for "long" homopolymer
    # runs.
    my $seq = shift;
    map {$_ = 0 } my ($polyAT_count, $polyA_count, $polyT_count);
    if ($seq =~ /TTTTTTTTTT/i || $seq =~ /AAAAAAAAAA/i) {
        if ($seq =~ /TTTTTTTTTT/i && $seq =~ /AAAAAAAAAA/i) {
            $polyAT_count++;
        }
        elsif ($seq =~ /AAAAAAAAAA/i) {
            $polyA_count++;
        }
        elsif ($seq =~ /TTTTTTTTTT/i) {
            $polyT_count++;
        }
    }
    return ($polyAT_count, $polyA_count, $polyT_count);
}


sub _update_totals {
    my ($self, $seq, $type) = @_;
    $annotation->{ $type }->{total}++;
    my ($polyAT_count, $polyA_count, $polyT_count) = $self->_assess_homopolymer_runs( $seq );
    if ($polyAT_count > 0) { $annotation->{ $type }->{polyAT}++ }
    if ($polyA_count  > 0) { $annotation->{ $type }->{polyA}++  }
    if ($polyT_count  > 0) { $annotation->{ $type }->{polyT}++  }
    return;
}


sub _print_category_report {
    my $self = shift;
    my $category = shift;

    my ($percent_category_reads, $percent_polyAT, $percent_polyA, $percent_polyT);

    # Means that the category is un-populated, so set it to 0 strictly
    # for calculation purposes--i.e., won't throw an error.
    if (!$annotation->{ $category }->{total}) { $annotation->{ $category }->{total} = 0 }

    # Calculations:
    $percent_category_reads = (($annotation->{ $category }->{total}  / $self->_total) * 100);

    if ($annotation->{$category }->{polyAT}) {
	$percent_polyAT = ($annotation->{$category }->{polyAT} == 0) ? 0 : (($annotation->{ $category }->{polyAT} / $annotation->{ $category }->{total}) * 100);
    }
    else {
	$percent_polyAT = 0;
	$annotation->{$category }->{polyAT} = 0;
    }

    if ($annotation->{$category }->{polyA}) {
	$percent_polyA  = ($annotation->{$category }->{polyA}  == 0) ? 0 : (($annotation->{ $category }->{polyA}  / $annotation->{ $category }->{total}) * 100);
    }
    else {
	$percent_polyA = 0;
	$annotation->{$category }->{polyA} = 0;
    }

    if ($annotation->{$category }->{polyT}) {
	$percent_polyT = ($annotation->{$category }->{polyT}  == 0) ? 0 : (($annotation->{ $category }->{polyT}  / $annotation->{ $category }->{total}) * 100);
    }
    else {
	$percent_polyT = 0;
	$annotation->{$category }->{polyT} = 0;
    }

    # TAB-DELIMITED FIELDS:
    # [0]  category
    # [1]  # reads in category
    # [2]  # total reads
    # [3]  % category reads in total reads
    # [4]  # polyAT reads in category
    # [5]  % polyAT reads in category
    # [6]  # polyA  reads in category
    # [7]  % polyA  reads in category
    # [8]  # polyT  reads in category
    # [9]  % polyT  reads in category
    unless ($annotation->{ $category }->{total} == 0) {
	print join (
		    "\t",
		    $category,
		    $annotation->{ $category }->{total},
		    $self->_total,
		    sprintf( "%.2f", $percent_category_reads ) . '%',
		    $annotation->{ $category }->{polyAT},
		    sprintf( "%.2f", $percent_polyAT ) . '%',
		    $annotation->{ $category }->{polyA},
		    sprintf( "%.2f", $percent_polyA ) . '%',
		    $annotation->{ $category }->{polyT},
		    sprintf( "%.2f", $percent_polyT ) . '%',
		    ) . "\n";
    }
    return;
}


__END__
