package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Model::Command::Build::ReferenceAlignment::AlignReads;
use Genome::Utility::PSL::Writer;
use Genome::Utility::PSL::Reader;
use File::Basename;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
    has => [
            fasta_file => {
                           doc => 'the file path to the fasta file of reads',
                           calculate_from => ['read_set_link'],
                           calculate => q|
                               return $read_set_link->full_path .'/'. $read_set_link->subset_name .'.fa';
                           |
                       },
            _alignment_files =>{
                               doc => "the file path to store the blat alignment",
                               calculate_from => ['read_set_link'],
                               calculate => q|
                                        return grep { -e $_ } glob($read_set_link->read_set_alignment_directory .'/'. $read_set_link->subset_name .'.psl.*');
                               |
                           },
            _aligner_output_files => {
                                     calculate_from => ['read_set_link'],
                                     calculate => q|
                                                  return grep { -e $_ } glob($read_set_link->read_set_alignment_directory .'/'. $read_set_link->subset_name .'.out.*');
                                             |
                                 },
        ],
};

sub help_brief {
    "Use blat plus to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads blat --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub should_bsub { 1;}


sub alignment_file {
    my $self = shift;

    my @alignment_files = $self->_alignment_files;
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
    my @aligner_output_files = $self->_aligner_output_files;
    unless (@aligner_output_files) {
        $self->error_message('Missing aligner output file');
        return;
    }
    if (scalar(@aligner_output_files) > 1) {
        die(scalar(@aligner_output_files) .' aligner output files found for '. $self->id);
    }
    return $aligner_output_files[0];
}

sub read_set_alignment_file {
    my $self = shift;
    return $self->read_set_link->read_set_alignment_directory .'/'. $self->read_set->subset_name .'.psl.'. $self->id;
}

sub read_set_aligner_output_file {
    my $self = shift;
    return $self->read_set_link->read_set_alignment_directory .'/'. $self->read_set->subset_name .'.out.'. $self->id;
}

sub read_set_aligner_error_file {
    my $self = shift;
    return $self->read_set_link->read_set_alignment_directory .'/'. $self->read_set->subset_name .'.err.'. $self->id;
}

sub execute {
    my $self = shift;

    my $read_set_data_directory = $self->read_set_link->full_path;
    unless (-e $read_set_data_directory) {
        unless ($self->create_directory($read_set_data_directory)) {
            $self->error_message("Failed to created read set data directory '$read_set_data_directory'");
            return;
        }
    }
    $DB::single = $DB::stopper;
    unless (-s $self->fasta_file) {
        unless($self->read_set->run_region_454->dump_library_region_fasta_file(filename => $self->fasta_file)) {
            $self->error_message('Failed to dump fasta file to '. $self->fasta_file .' for event '. $self->id);
            return;
        }
    }
    # check_for_existing_alignment_files
    my $read_set_alignment_directory = $self->read_set_link->read_set_alignment_directory;
    if (-d $read_set_alignment_directory) {
        my $errors;
        $self->status_message("found existing run directory $read_set_alignment_directory");
        my $alignment_file = $self->alignment_file;
        my $aligner_output_file = $self->aligner_output_file;
        unless (-s $alignment_file && -s $aligner_output_file) {
            $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
            unless (rename ($read_set_alignment_directory,$read_set_alignment_directory . ".old.$$")) {
                die "Failed to move old alignment directory out of the way: $!";
            }
            # fall through to the regular processing and try this again...
        } else {
            $self->status_message("SHORTCUT SUCCESS: alignment data is already present.");
            return 1;
        }
    }
    $self->create_directory($read_set_alignment_directory);

    my $model = $self->model;
    my @ref_seq_paths = grep {$_ !~ /all_sequences/ } $model->get_subreference_paths(reference_extension => 'fa');

    my $blat_params = '-mask=lower -out=pslx -noHead';
    $blat_params .= $model->read_aligner_params || '';

    my $blat_subjects = Genome::Model::Tools::Blat::Subjects->create(
                                                                     query_file => $self->fasta_file,
                                                                     subject_files => \@ref_seq_paths,
                                                                     blat_params => $blat_params,
                                                                     psl_path => $self->read_set_alignment_file,
                                                                     blat_output_path => $self->read_set_aligner_output_file
                                                                 );
    unless ($blat_subjects->execute) {
        $self->error_message('Failed to execute '. $blat_subjects->command_name .' for '.
                             $self->fasta_file ." against:\n". join ("\n",@ref_seq_paths));
        return;
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    my $align_file = $self->alignment_file;
    unless (-f $align_file && -s $self->alignment_file) {
        $self->error_message("Failed to verify successfule completion of event ". $self->id .
                             "\nFile $align_file does not exist or has 0 size");
        return;
    }

    my $output_file = $self->aligner_output_file;
    unless(-f $output_file && -s $output_file) {
        $self->error_message("Failed to verify successfule completion of event ". $self->id .
                             "\nFile $output_file does not exist or has 0 size");
        return;
    }
    return 1;
}


1;

