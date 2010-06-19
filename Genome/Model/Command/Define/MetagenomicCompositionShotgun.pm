package Genome::Model::Command::Define::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;


class Genome::Model::Command::Define::MetagenomicCompositionShotgun {
    is => 'Genome::Model::Command::Define',
    has => [
        subject_class_name => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            default_value => 'Genome::Sample',
            doc => 'The Perl class name of the subject whose ID is subject_id'  
        },
        processing_profile_name => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            default_value => 'human microbiome metagenomic alignment with samtools merge',
            doc => 'identifies the processing profile by name',
        },
        # TODO: move these up, and make this subclass default to true for both values        
        assign_all_instrument_data => {
            default_value => 0,
            doc => 'assigns all available instrument data for the subject immediately',
        },
        build => {
            default_value => 0,
            doc => 'start building immediately',
        },
   ],
};

sub help_synopsis {
    return <<EOS;
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-cDNA-1

genome model define metagenomic-composition-shotgun \
    --subject-name H_LA-639-9080-cDNA-1 \
    --processing-profile-name "human microbiome metageomic shotgun"
EOS
}

# We'll eventually give explicit control over references used, though right now they're
# part of the processing profile.
#
# genome model define metagenomic-composition-shotgun \
#    --subject-name H_LA-639-9080-cDNA-1 \
#    --contamination-reference 12345
#    --metagenomic-references 678,910
#    --processing-profile-name "? ? metageomic shotgun"

sub help_detail {
    return "" 
}

1;

__END__

PLAN FORWARD:

1. This works:
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 
genome model instrument-data assign -m ??? --all
genome model build start

2. This works, and does the above for you
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 

3. This works: 
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 --conamination-reference C --metagenomic-references M1,M2

