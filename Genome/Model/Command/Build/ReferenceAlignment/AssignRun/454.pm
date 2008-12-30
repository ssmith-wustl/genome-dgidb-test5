package Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::AssignRun::454 {
    is => 'Genome::Model::Command::Build::ReferenceAlignment::AssignRun',
    has => [
            sff_file => {
                         calculate_from => ['instrument_data'],
                         calculate => q|
                             return $instrument_data->sff_file;
                         |,
                     },
        ],
};

sub help_brief {
    "Creates the appropriate items on the filesystem for a new 454 run region to be aligned"
}

sub help_synopsis {
    return <<EOS
This command dumps and/or links instrument data to the filesystem in preparation of alignment.
EOS
}

sub help_detail {
    return <<EOS
    This command is launched automatically by build reference-alignment
    when it is determined that the run is from a 454.  The sff file is
    dumped to the filesystem if needed.
EOS
}

# TODO: If the amplicons are always the same for the model, then move up to model.
sub amplicon_header_file {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    return $instrument_data->full_path .'/amplicon_headers.txt';
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $instrument_data = $self->instrument_data;
    unless ($instrument_data->dump_to_file_system) {
        $self->error_message('Failed to dump sff file to file system');
        return;
    }
    if (-e $self->amplicon_header_file) {
        $self->status_message('Amplicon header file already exists: '. $self->amplicon_header_file);
    } else {
        my $fh = $self->create_file('amplicon_header_file',$self->amplicon_header_file);
        # Close the filehandle, delete and let the tool re-open filehandle
        $fh->close;
        unlink($self->amplicon_header_file);
        my $amplicon = Genome::Model::Command::Report::Amplicons->create(
                                                                         sample_name => $instrument_data->sample_name,
                                                                         output_file => $self->amplicon_header_file,
                                                                     );
        unless ($amplicon) {
            $self->error_message('Failed to create amplicon report tool');
            return;
        }
        unless ($amplicon->execute) {
            $self->error_message('Failed to execute command '. $amplicon->command_name);
            return;
        }
    }
    return $self->verify_successful_completion
}

sub verify_successful_completion {
    my $self = shift;

    unless (-e $self->sff_file) {
        $self->error_message('Failed to find sff file '. $self->sff_file);
        return;
    }
    unless (-s $self->sff_file) {
        $self->error_message('Sff file does not exist or has zero size: '. $self->sff_file);
        return;
    }
    unless (-e $self->amplicon_header_file) {
        $self->error_message('The amplicon header file does not exist: '. $self->amplicon_header_file);
        return;
    }
    return 1;
}

1;

