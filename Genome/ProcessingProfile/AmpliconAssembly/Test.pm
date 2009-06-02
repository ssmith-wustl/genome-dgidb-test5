package Genome::ProcessingProfile::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::ProcessingProfile::AmpliconAssembly';
}

sub params_for_test_class {
    return (
        name => '16S Composition 27F to 1492R (907R)',
        assembler => 'phredphrap',
        assembly_size => 1465,
        primer_amp_forward => '18SEUKF:ACCTGGTTGATCCTGCCAG',
        primer_amp_reverse => '18SEUKR:TGATCCTTCYGCAGGTTCAC',
        primer_seq_forward => '502F:GGAGGGCAAGTCTGGT',
        primer_seq_reverse => '1174R:CCCGTGTTGAGTCAAA',
        purpose => 'composition',
        region_of_interest => '16S',
        sequencing_center => 'gsc',
        sequencing_platform => 'sanger',
    );
}

sub required_attrs {
    return (qw/ name assembler assembly_size primer_amp_forward primer_amp_reverse purpose region_of_interest sequencing_center sequencing_platform /);
}

sub invalid_params_for_test_class {
    return (
        primer_amp_forward => 'AAGGTGAGCCCGCGATGCGAGCTTAT',
        primer_amp_reverse => '55:55',
        sequencing_platform => 'super-seq',
        sequencing_center => 'monsanto',
        purpose => 'because',
    );
}

#< MOCK ># 
sub create_mock_processing_profile {
    my $self = shift;

    my $pp = $self->create_mock
        or confess "Can't create mock processing profile for amplicon assembly\n";

    $pp->set_always('sense_primer_fasta', $self->dir.'/sense.fasta');
    confess "No sense primer fasta in ".$self->dir."\n" unless -f $pp->sense_primer_fasta;
    $pp->set_always('anti_sense_primer_fasta', $self->dir.'/anti_sense.fasta');
    confess "No anti sense primer fasta in ".$self->dir."\n" unless -f $pp->anti_sense_primer_fasta;

    # Genome::ProcessingProfile::AmpliconAssembly
    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile::AmpliconAssembly',
        (qw/ 
            stages params_for_class
            assemble_objects assemble_job_classes
            /),
    );

    #Genome::ProcessingProfile
    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile',
        (qw/
            objects_for_stage classes_for_stage
            verify_successful_completion_objects verify_successful_completion_job_classes
            /),
    );

    return $pp;
}

1;

#$HeadURL$
#$Id$
