package Genome::Model::Tools::BioSamtools::ReadLengthDistribution;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::ReadLengthDistribution {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        output_file => {
            is => 'Text',
            doc => 'The output directory to generate peak files',
        },
    ],
    has_optional => [
        _output_fh => {},
    ],
};

sub execute {
    my $self = shift;
    my $output_fh = Genome::Utiltity::FileSystem->open_file_for_writing($self->output_file);
    $self->_output_fh($output_fh);
    my $refcov_bam  = Genome::RefCov::Bam->new(bam_file => $self->bam_file );
    unless ($refcov_bam) {
        die('Failed to load bam file '. $self->bam_file);
    }
    my $bam  = $refcov_bam->bio_db_bam;
    my $header = $bam->header();
    my %read_stats;
    my $read_stats = Statistics::Descriptive::Sparse->new();
    my %alignment_stats;
    my $alignment_stats = Statistics::Descriptive::Sparse->new();
    while (my $align = $bam->read1()) {
        my $flag = $align->flag;
        my $read_length = $align->l_qseq;
        $read_stats->add_data($read_length);
        $read_stats{$read_length}++;
        unless ($flag & 4) {
            my $align_length = $align->calend - $align->pos;
            $alignment_stats{$align_length}++;
            $alignment_stats->add_data($align_length);
        }
    }
    print $output_fh 'READ SUMMARY:' ."\n";
    $self->print_stats($read_stats,\%read_stats);
    print $output_fh 'ALIGNED SUMMARY:' ."\n";
    $self->print_stats($alignment_stats,\%alignment_stats);
    $self->_output_fh->close;
    return 1;
}

sub print_stats {
    my $self = shift;
    my $stats = shift;
    my $histogram = shift;
    my $output_fh = $self->_output_fh;
    print $output_fh "\tCount:\t". $stats->count ."\n";
    print $output_fh "\tMinimum:\t". $stats->min ."\n";
    print $output_fh "\tMaximum:\t". $stats->max ."\n";
    my $partitions = $stats->max - $stats->min + 1;
    print $output_fh "\tMean:\t". $stats->mean ."\n";
    print $output_fh "\tStdDev:\t". $stats->standard_deviation ."\n";
    for my $key (sort {$a <=> $b} keys %{$histogram}) {
        print $output_fh "\t$key:\t". $$histogram{$key} ."\n";
    }
}


1;
