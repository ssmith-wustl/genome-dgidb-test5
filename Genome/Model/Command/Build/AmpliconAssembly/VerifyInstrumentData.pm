package Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use Genome::Utility::FileSystem;

class Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData {
    is => 'Genome::Model::Event',
};

#< Subclassing...don't >#
sub _get_sub_command_class_name {
  return __PACKAGE__;
}

#< LSF >#
sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

#< The Beef >#
sub execute {
    my $self = shift;

    if ( $self->model->sequencing_center eq 'gsc' ) {
        $self->_link_instrument_data
            or return;
    }

    return $self->model->amplicons; # Error msg is on model if no amplicons
}

sub _link_instrument_data {
    my $self = shift;

    my $chromat_dir = $self->model->chromat_dir;
    for my $ida ( $self->model->instrument_data_assignments ) {
        $self->_dump_unbuilt_instrument_data($ida) or return;

        my $instrument_data_dir = $ida->instrument_data->resolve_full_path;
        my $dh = Genome::Utility::FileSystem->open_directory($instrument_data_dir)
            or return;

        while ( my $trace = $dh->read ) {
            next if $trace =~ m#^\.#;
            my $target = sprintf('%s/%s', $instrument_data_dir, $trace);
            my $link = sprintf('%s/%s', $chromat_dir, $trace);
            Genome::Utility::FileSystem->create_symlink($target, $link)
                or return;
        }
    }

    return 1;
}

sub _dump_unbuilt_instrument_data {
    my $self = shift;
    my $ida = shift;
    unless ( $ida->first_build_id ) {
        unless ( $ida->instrument_data->dump_to_file_system ) {
            $self->error_message(
                sprintf(
                    'Error dumping instrument data (%s <ID: %s) for model (%s <ID %s)',
                    $ida->instrument_data->run_name,
                    $ida->instrument_data->id,
                    $self->model->name,
                    $self->model->id,
                )
            );
            return;
        }
        $ida->first_build_id( $self->build_id );
    }
    return 1;
}

1;

#$HeadURL$
#$Id$
