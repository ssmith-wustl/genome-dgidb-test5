package Genome::Model::Tools::SmallRna::ClusterCoverage;

use strict;
use warnings;

use Genome;
use Workflow;


my $DEFAULT_ZENITH = '5';
class Genome::Model::Tools::SmallRna::ClusterCoverage {
    is => ['Genome::Model::Tools::SmallRna::Base'],
    has_input => [
        bam_file => {
        	is => 'Text',
            doc => 'Input file of BAM alignments',
        },
        zenith_depth => {
            is => 'Text',
            is_output=> 1,
            doc => 'Minimum zepth depth cutoff',
            default_value => $DEFAULT_ZENITH,
        },
        stats_file => {
            is => 'Text',
            is_output=> 1,
            doc => 'Output file of coverage statistics ',
        },
        bed_file => {
            is => 'Text',
            is_output=> 1,
            doc => 'Output "Regions" BED file containing CLUSTERS from MERGED BED entries',
        },
    ],
};


sub execute {
    my $self = shift;
    
    
    my $cmd = '/usr/bin/perl `which gmt` bio-samtools cluster-coverage --bam-file='. $self->bam_file .' --minimum-zenith='. $self->zenith_depth .' --stats-file='. $self->stats_file .' --bed-file='. $self->bed_file ;
    
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->bed_file,$self->stats_file],
    );
    
    return 1;   
}

1;

__END__

/usr/bin/perl `which gmt` bio-samtools cluster-coverage 
--bam-file=/gscmnt/sata141/techd/jhundal/miRNA/64LY0AAXX_AML/NEW_FAR/Lane3_filtered.bam 
--minimum-zenith=5 
--bed-file=/gscmnt/sata141/techd/jhundal/miRNA/64LY0AAXX_AML/NEW_FAR/Lane3_zenith5.bed 
--stats-file=/gscmnt/sata141/techd/jhundal/miRNA/64LY0AAXX_AML/NEW_FAR/Lane3_coverage_stats.tsv
