package Genome::ProcessingProfile::ShortRead;

use strict;
use warnings;

use above "Genome";

my @PARAMS = qw/
                align_dist_threshold
                dna_type
                genotyper_name
                genotyper_params
                indel_finder_name
                indel_finder_params
                multi_read_fragment_strategy
                prior_ref_seq
                read_aligner_name
                read_aligner_params
                read_calibrator_name
                read_calibrator_params
                reference_sequence_name
                sequencing_platform
               /;

class Genome::ProcessingProfile::ShortRead {
    is => 'Genome::ProcessingProfile',
    has => [
            ( map { $_ => {
                           via => 'params',
                           to => 'value',
                           where => [name => $_],
                           is_mutable => 1
                       },
                   } @PARAMS
         ),
        ],
};


sub prior {
    my $self = shift;
    warn("For now prior has been replaced with the actual column name prior_ref_seq");
    if (@_) {
        die("Method prior() is read-only since it's deprecated");
    }
    return $self->prior_ref_seq();
}

sub params_for_class {
    my $class = shift;
    return @PARAMS;
}

sub filter_ruleset_name {
    #TODO: move into the db so it's not constant
    'basic'
}

sub filter_ruleset_params {
    ''
}


1;
