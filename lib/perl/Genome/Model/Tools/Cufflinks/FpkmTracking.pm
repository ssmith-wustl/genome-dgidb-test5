package Genome::Model::Tools::Cufflinks::FpkmTracking;

use strict;
use warnings;

use Genome;
use Math::Round;

class Genome::Model::Tools::Cufflinks::FpkmTracking {
    is => ['Command'],
    has => [
        fpkm_tracking_file => {
            is => 'Text',
            doc => 'An isoforms.fpkm_tracking file output from cufflinks.',
        },
        output_summary_tsv => {
            is => 'Text',
            doc => 'An output summary file with tab-separated values.',
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input => $self->fpkm_tracking_file,
        separator => "\t",
    );
    my %coverage;
    my %fpkm;
    my %stats;
    while (my $data = $reader->next) {
        # Example data structure for isoforms.fpkm_tracking
        # $data = {
        #  'coverage' => '0',
        #  'tss_id' => '-',
        #  'gene_id' => 'Xkr4',
        #  'status' => 'OK',
        #  'FPKM_conf_lo' => '0',
        #  'locus' => '1:3204562-3661579',
        #  'gene_short_name' => 'Xkr4',
        #  'tracking_id' => 'ENSMUST00000070533',
        #  'class_code' => '-',
        #  'length' => '3634',
        #  'FPKM' => '0',
        #  'nearest_ref_id' => '-',
        #  'FPKM_conf_hi' => '0'
        #};
        $stats{total}++;
        $stats{$data->{status}}++;
        my $coverage = $data->{coverage};
        if ($coverage =~ /\d+/) {
            if ($coverage > 0) {
                $stats{touched}++;
            }
            $coverage = round($coverage);
        }
        $coverage{ $coverage }++;
        my $fpkm = $data->{FPKM};
        $fpkm = sprintf("%.01f", $fpkm);
        $fpkm{ $fpkm }++;
    }
    my @headers = sort { $a cmp $b } keys %stats;
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        output => $self->output_summary_tsv,
        separator => "\t",
        headers => \@headers,
    );
    $writer->write_one(\%stats);
    #for my $bin (sort {$a <=> $b} keys %fpkm) {
    #    print $bin ."\t". $fpkm{$bin} ."\n";
    #}
    #for my $key (sort keys %stats) {
    #    print $key ."\t". $stats{$key} ."\n";
    #}
    return 1;
};


1;
