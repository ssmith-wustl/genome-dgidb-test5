
package Genome::ProcessingProfile::ImportedReferenceSequence;

#:eclark 11/16/2009 Code review.

# Seems like there should better way to define a build that only does one thing.  Aside from that, this module has no problems (because it does nothing.)

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedReferenceSequence{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        bwa_version => {
            doc => 'specify a specific bwa version to use for bwa index command',
            is_optional => 1,
        },
        maq_version => {
            doc => 'specify a specific maq version to use for maq fasta2bfa command',
            is_optional => 1,
        },
        samtools_version => {
            doc => 'specify a specific samtools version for SamToBam, samtools merge, etc...',
            is_optional => 1,
        },
    ]
};

sub stages {
    return (qw/
              imported_reference_sequence
            /);
}

sub imported_reference_sequence_job_classes {
    return (qw/
            Genome::Model::Event::Build::ImportedReferenceSequence::Run
            /);
}

sub imported_reference_sequence_objects {
    return 1;
}
