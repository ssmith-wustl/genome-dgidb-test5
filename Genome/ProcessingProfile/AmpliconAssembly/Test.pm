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
        name => '18S Composition 18SEUKF to 18SEUKR (502F, 1174R)',
        assembler => 'phredphrap',
        assembly_size => 1900,
        primer_amp_forward => '18SEUKF:ACCTGGTTGATCCTGCCAG',
        primer_amp_reverse => '18SEUKR:TGATCCTTCYGCAGGTTCAC',
        primer_seq_forward => '502F:GGAGGGCAAGTCTGGT',
        primer_seq_reverse => '1174R:CCCGTGTTGAGTCAAA',
        purpose => 'composition',
        region_of_interest => '18S',
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

    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile::AmpliconAssembly',
        (qw/ 
            stages params_for_class
            /),
    );

    return $pp;
}

1;

#$HeadURL$
#$Id$
