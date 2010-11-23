package Genome::InstrumentData::Command::Dacc::Import;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require File::Path;

class Genome::InstrumentData::Command::Dacc::Import {
    is  => 'Genome::InstrumentData::Command::Dacc',
    is_abstract => 1,
};

sub help_brief {
    return 'Import dl\'d instrument data from the DACC';
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    $self->status_message('Import: '.$self->sra_sample_id.' '.$self->format);

    my $sample = $self->_get_sample;
    if ( not $sample ) {
        $self->error_message('Cannot get sample for '.$self->sra_sample_id);
        return;
    }

    my $main_inst_data = $self->_get_instrument_data(create_allocation => 0);
    return if not $main_inst_data;

    my $dl_dir_ok = $self->_dl_directory_exists;
    return if not $dl_dir_ok;

    my $md5s_ok = $self->_validate_md5;
    return if not $md5s_ok;

    my $sub_execute_ok = $self->_execute;
    return if not $sub_execute_ok;

    my $update = $self->_update_instrument_data;
    return if not $update;

    if ( $self->_xml_files ) {
        $self->_update_library;
    }

    $self->status_message('Import...OK');

    return 1;
}

1;

