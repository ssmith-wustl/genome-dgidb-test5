package Genome::InstrumentData::Command::Dacc::Import::Sff;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Copy;

class Genome::InstrumentData::Command::Dacc::Import::Sff {
    is  => 'Genome::InstrumentData::Command::Dacc::Import',
    has => [
        format => {
            is => 'Text',
            is_constant => 1,
            value => 'sff',
        },
    ],
};

sub help_brief {
    return 'Import the downloaded SFFs from the DACC';
}

sub help_detail {
    return help_brief();
}

sub _execute {
    my $self = shift;

    my @sffs = $self->existing_data_files;
    my $instrument_data = $self->_instrument_data;

    my $instrument_data_needed = scalar(@sffs) - scalar(@$instrument_data);
    if ( $instrument_data_needed > @$instrument_data ) {
        $self->error_message('Somehow there are more instrument data than SFFs to import. Please fix.');
        return;
    }

    # make an inst data w/ allocation for each
    for ( my $i = 1; $i <= $instrument_data_needed; $i++ ) {
        my $kilobytes_requested = -s $sffs[$i];
        $kilobytes_requested = int($kilobytes_requested / 900); # give a little brethin room
        my $instrument_data = $self->_create_instrument_data(kilobytes_requested => $kilobytes_requested);
        if ( not $instrument_data ) {
            $self->error_message('Cannot create instrument data');
            return;
        }
    }

    $instrument_data = $self->_instrument_data;
    if ( @$instrument_data != @sffs ) {
        $self->error_message('Tried to create an instrument data for each SFF, but failed.');
        return;
    }

    for ( my $i = 0; $i <= $#sffs; $i++ ) {
        my $inst_data = $instrument_data->[$i];
        my $destination_file = $inst_data->archive_path;
        if ( not $destination_file ) {
            $self->error_message('No destination file for instrument data: '.$inst_data->id);
            return;
        }
        my $sff = $sffs[$i];
        my $size = -s $sff;
        $self->status_message("Move $sff to $destination_file");
        my $move_ok = File::Copy::move($sff, $destination_file);
        #rename $sff, $destination_file;
        if ( not $move_ok ) {
            $self->error_message("Failed to move SFF $sff to $destination_file: $!");
            return;
        }
        if ( not -e $destination_file ) {
            $self->error_message('Move succeeded, but destination file does not exist.');
            return;
        }
        if ( $size != -s $destination_file ) {
            $self->error_message("Moved SFF $sff to $destination_file but now file size is different.");
            return;
        }
        $instrument_data->[$i]->original_data_path($sff);
        my $sff_base_name = File::Basename::basename($sff);
        $instrument_data->[$i]->description($self->sra_sample_id." SFF $sff_base_name from the DACC");
    }

    return 1;
}

1;

