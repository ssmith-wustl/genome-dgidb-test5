package Genome::Model::Tools::SmrtAnalysis::ContigConsensus;

use strict;
use warnings;

use Genome;

use Workflow;
use Workflow::Simple;




class Genome::Model::Tools::SmrtAnalysis::ContigConsensus {
    is =>  ['Genome::Model::Tools::SmrtAnalysis::Base'],
    has_input => [
        reference_contig_name => {
            is => 'Text',
            doc => 'The name of the reference contig or chromosome.',
        },
        data_directory => {
            is => 'Text',
            doc => 'The job data directory.',
        },
        alignment_summary_gff => {
            is => 'Text',
            doc => 'An alignment summary GFF3 format file.',
        },
    ],
    has_optional_input => [

        min_variant_quality => {
            is => 'Number',
            default_value => 0,
        },
        min_coverage => {
            is => 'Number',
            default_value => 4,
        },
        max_coverage => {
            is => 'Number',
            default_value => 500,
        },
        
    ],
    has_optional_output => [
          consensus_params => { },
    ],      
    has_optional => {
        
    },
};

sub help_brief {
    ''
}


sub help_detail {
    return <<EOS 

EOS
}

sub execute {
    my $self = shift;

    
    
    
    #Maybe we should just create the params rather than running another workflow
    $self->consensus_params(\@evi_cons_params);
    return 1;
}








1;
