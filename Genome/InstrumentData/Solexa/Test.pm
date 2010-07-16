package Genome::InstrumentData::Solexa::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::InstrumentData::Solexa';
}

sub create_mock_instrument_data {
    my $self = shift;

    my $mock = UR::Object::create_mock(
        'Genome::InstrumentData::Solexa',
        id => -11111,
        run_name =>'090505_HWUSI-EAS626_96980044_302M2',
        sequencing_platform => 'solexa',
        seq_id => -11111,
        sample_name => 'U_RR-090305_gDNA_KLE1260_tube1',
        subset_name => 3,
        library_name => 'U_RR-090305_gDNA_KLE1260_tube1-lib1',
    ) or confess "Can't create mock solexa instrument data\n";

    $mock->set_always('flow_cell_id', '302M2');
    $mock->set_always('lane', '3');
    $mock->set_list('dump_sanger_fastq_files', glob($self->dir.'/*.fastq'));

    return $mock;
}

1;

#$HeaderURL$
#$Id: Solexa.pm 47405 2009-06-01 02:20:26Z ssmith $
