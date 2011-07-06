package Genome::Model::Tools::Sx::Metrics;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Metrics {
    has => [
        count => { calculate_from => [qw/ _metrics /], calculate => q| return $_metrics->{count} |, },
        bases => { calculate_from => [qw/ _metrics /], calculate => q| return $_metrics->{bases} |, },
        _metrics => {
            is => 'Hash',
            is_optional => 1,
            default_value => {
                bases => 0, 
                count => 0,
            }, 
        },
    ],
};

sub add_sequence {
    my ($self, $seq) = @_;

    $self->_metrics->{bases} += length($seq->{seq});
    $self->_metrics->{count}++;

    return 1;
}

sub add_sequences {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        $self->add_sequence($seq);
    }

    return 1;
}

sub to_string {
    my $self = shift;

    my $string;
    for my $metric (qw/ bases count /) {
        $string .= $metric.'='.$self->$metric."\n";
    }

    return $string;
}

sub read_from_file {
    my ($class, $file) = @_;

    if ( not $file ) {
        $class->error_message('No file given to create metrics from file');
        return;
    }

    if ( not -s $file ) {
        $class->error_message('Failed to read metrics from file. File ('.$file.') does not exist.');
        return;
    }

    my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
    if ( not $fh ) {
        $class->error_message("Failed to open file ($file)");
        return;
    }

    my %metrics;
    while ( my $line = $fh->getline ) {
        chomp $line;
        my ($key, $val) = split('=', $line);
        $metrics{$key} = $val;
    }
    $fh->close;

    my $self = Genome::Model::Tools::Sx::Metrics->create(_metrics => \%metrics);
    if ( not $self ) {
        $class->error_message("Failed to create metrics object from file ($file) with metrics: ".Data::Dumper::Dumper(\%metrics));
        return;
    }

    return $self;
}

sub write_to_file {
    my ($self, $file) = @_;

    if ( not $file ) {
        $self->error_message('No file given to create metrics from file');
        return;
    }

    unlink $file;
    my $fh = eval{ Genome::Sys->open_file_for_writing($file); };
    if ( not $fh ) {
        $self->error_message("Failed to open file ($file)");
        return;
    }
    $fh->print($self->to_string);
    $fh->close;

    return 1;
}

1;

