package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
    has => [
            sff_file => {
                         calculate_from => ['instrument_data'],
                         calculate => q|
                             return $instrument_data->sff_file;
                         |,
                     },
            fasta_file => {
                           doc => 'the file path to the fasta file for instrument data',
                           calculate_from => ['instrument_data'],
                           calculate => q|
                               return $instrument_data->full_path .'/'. $instrument_data->subset_name .'.fa';
                           |
                       },
            _existing_alignment_files =>{
                               doc => "the file path to store the blat alignment",
                               calculate_from => ['instrument_data_assignment'],
                               calculate => q|
                                        return grep { -e $_ } glob($instrument_data_assignment->alignment_directory .'/'. $instrument_data_assignment->subset_name .'.psl.*');
                               |
                           },
            _existing_aligner_output_files => {
                                     calculate_from => ['instrument_data_assignment'],
                                     calculate => q|
                                                  return grep { -e $_ } glob($instrument_data_assignment->alignment_directory .'/'. $instrument_data_assignment->subset_name .'.out.*');
                                             |
                                 },
        ],
};

sub help_brief {
    "Use blat to align instrument data reads";
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment align-reads blat --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the build process
EOS
}

sub should_bsub { 1;}


sub alignment_file {
    my $self = shift;

    my @alignment_files = $self->_existing_alignment_files;
    unless (@alignment_files) {
        $self->error_message('Missing alignment file');
        return;
    }
    if (scalar(@alignment_files) > 1) {
        die(scalar(@alignment_files) .' alignment files found for '. $self->id);
    }
    return $alignment_files[0];
}

sub aligner_output_file {
    my $self = shift;
    my @aligner_output_files = $self->_existing_aligner_output_files;
    unless (@aligner_output_files) {
        $self->error_message('Missing aligner output file');
        return;
    }
    if (scalar(@aligner_output_files) > 1) {
        die(scalar(@aligner_output_files) .' aligner output files found for '. $self->id);
    }
    return $aligner_output_files[0];
}

sub instrument_data_alignment_file {
    my $self = shift;

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;
    return $alignment->alignment_directory .'/'. $self->instrument_data->subset_name .'.psl.'. $self->id;
}

sub instrument_data_aligner_output_file {
    my $self = shift;

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;
    return $alignment->alignment_directory .'/'. $self->instrument_data->subset_name .'.out.'. $self->id;
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;

    my $instrument_data_directory = $self->instrument_data->full_path;
    unless (-e $instrument_data_directory) {
        unless ($self->create_directory($instrument_data_directory)) {
            $self->error_message("Failed to create instrument data directory '$instrument_data_directory'");
            return;
        }
    }
    unless (-s $self->fasta_file) {
        unless (-e $self->sff_file) {
            $self->error_message('Failed to find sff_file: '. $self->sff_file);
            return;
        }
        my $fasta_tool = Genome::Model::Tools::454::Sffinfo->create(
                                                                    sff_file => $self->sff_file,
                                                                    output_file => $self->fasta_file,
                                                                    params => '-s',
                                                                );
        unless ($fasta_tool) {
            $self->error_message('Failed create fasta conversion tool');
            return;
        }
        unless ($fasta_tool->execute) {
            $self->error_message('Failed to execute command '. $fasta_tool->command_name);
            return;
        }
    }
    # check_for_existing_alignment_files
    my $alignment_directory = $alignment->alignment_directory;
    if ($alignment_directory && -d $alignment_directory) {
        my $errors;
        $self->status_message("found existing run directory $alignment_directory");
        my $alignment_file = $self->alignment_file;
        my $aligner_output_file = $self->aligner_output_file;
        unless (-s $alignment_file && -s $aligner_output_file) {
            $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
            unless (rename ($alignment_directory,$alignment_directory . ".old.$$")) {
                die "Failed to move old alignment directory out of the way: $!";
            }
            # fall through to the regular processing and try this again...
        } else {
            $self->status_message("SHORTCUT SUCCESS: alignment data is already present.");
            return $self->verify_successful_completion;
        }
    }
    unless ($alignment_directory) {
        $alignment_directory = $alignment->get_or_create_alignment_directory;
    }
    unless (Genome::Utility::FileSystem->lock_resource(
                                                       lock_directory => $alignment_directory,
                                                       resource_id => $self->instrument_data->id,
                                                   )) {
        $self->error_message('Failed to create lock for resource '. $self->instrument_data->id);
        return;
    }
    $self->status_message("No alignment files found...beginning processing and setting marker to prevent simultaneous processing.");
    $self->create_directory($alignment_directory);
    my $model = $self->model;
    my @ref_seq_paths = grep {$_ !~ /all_sequences/ } $model->get_subreference_paths(reference_extension => 'fa');
    unless (scalar(@ref_seq_paths)) {
        $self->error_message('No reference sequences found: '. $model->reference_sequence_path);
        return;
    }

    my $blat_params = '-mask=lower -out=pslx -noHead';
    $blat_params .= $model->read_aligner_params || '';

    my $blat_subjects = Genome::Model::Tools::Blat::Subjects->create(
                                                                     query_file => $self->fasta_file,
                                                                     subject_files => \@ref_seq_paths,
                                                                     blat_params => $blat_params,
                                                                     psl_path => $self->instrument_data_alignment_file,
                                                                     blat_output_path => $self->instrument_data_aligner_output_file
                                                                 );
    unless ($blat_subjects->execute) {
        $self->error_message('Failed to execute '. $blat_subjects->command_name .' for '.
                             $self->fasta_file ." against:\n". join ("\n",@ref_seq_paths));
        return;
    }
    unless (Genome::Utility::FileSystem->unlock_resource(
                                                         lock_directory => $alignment_directory,
                                                         resource_id => $self->instrument_data->id,
                                                     )) {
        $self->error_message('Failed to unlock resource '. $self->instrument_data->id);
        return;
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;

    my $alignment_directory = $alignment->alignment_directory;
    unless ($alignment_directory && -d $alignment_directory) {
        $self->error_message('Alignment directory is not found: '. $alignment_directory);
        return;
    }
    unless ($self->alignment_file) {
        $self->error_message('Alignment file does not exist!');
        return;
    }
    unless (-s $self->alignment_file) {
        $self->error_message('Alignment file has zero size: '. $self->alignment_file);
        return;
    }
    unless ($self->aligner_output_file) {
        $self->error_message('Aligner output file does not exist!');
        return;
    }
    unless (-s $self->aligner_output_file) {
        $self->error_message('Aligner output file has zero size: '. $self->aligner_output_file);
        return;
    }
    return 1;
}


1;

