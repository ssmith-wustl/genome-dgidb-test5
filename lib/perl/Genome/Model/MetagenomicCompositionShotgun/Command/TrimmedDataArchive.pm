package Genome::Model::MetagenomicCompositionShotgun::Command::TrimmedDataArchive;

use strict;
use warnings;
use Genome;
use File::stat;

class Genome::Model::MetagenomicCompositionShotgun::Command::ImportedDataArchive {
    is => 'Genome::Command::OO',
    doc => '',
    has => [
        model_id => {
            is => 'Int',
        },
    ],
};

sub execute {
    my $self = shift;

    my $mcs_model = Genome::Model->get($self->model_id);
    my ($meta_model) = $mcs_model->_metagenomic_alignment_models;
    my @imported_data = map {$_->instrument_data} $meta_model->instrument_data_assignments;
    print "WARNING: This data is in an unverified quality format do not assume it is in Sanger quality format.\n"
    for my $imported_data (@imported_data) {
        print $imported_data->archive_path . "\n";
    }
}

1;
