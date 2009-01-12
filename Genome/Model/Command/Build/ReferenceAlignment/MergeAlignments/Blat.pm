package Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Blat;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Blat {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments',
       ],
};

sub help_brief {
    "Merge all blat alignments and sequence data for downstream analysis";
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment merge-alignments blat --model-id
EOS
}

sub help_detail {
    return <<EOS
This command merges the blat alignments and sequence data for all input
instrument data in a 454 reference-alignement model.  In addition, we create
a Bio::Db fasta formatted directory for use in later commands.
EOS
}

sub should_bsub { 1;}


sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $start = UR::Time->now;
    my $model = $self->model;

    # Create the model alignments director if it does not exist
    my $alignments_dir = $self->build->accumulated_alignments_directory;
    unless (-e $alignments_dir) {
        unless ($self->create_directory($alignments_dir)) {
            $self->error_message("Failed to create directory '$alignments_dir':  $!");
            return;
        }
    } else {
        unless (-d $alignments_dir) {
            $self->error_message("File already exist for directory '$alignments_dir':  $!");
            return;
        }
    }

    # Collect all the alignment files, aligner output files, and sff files for all read sets
    my @alignment_events = $model->alignment_events;
    unless (scalar(@alignment_events)) {
        $self->error_message('No alignment events found for model '. $model->id );
        return;
    }
    my @alignment_files;
    my @aligner_output_files;
    my @sff_files;
    for my $alignment_event (@alignment_events) {
        my $alignment_file = $alignment_event->alignment_file;
        unless ($alignment_file) {
            $self->error_message('Failed to find alignment_file for event '. $alignment_event->id);
            return;
        }
        push @alignment_files, $alignment_file;

        my $aligner_output_file = $alignment_event->aligner_output_file;
        unless ($aligner_output_file) {
            $self->error_message('Failed to find aligner_output_file for event '. $alignment_event->id);
            return;
        }
        push @aligner_output_files, $aligner_output_file;
        my $instrument_data = $alignment_event->instrument_data;
        push @sff_files, $instrument_data->sff_file;
    }

    # Merge the blat alignments and aligner output
    my $cat_blat_tool = Genome::Model::Tools::Blat::Cat->create(
                                                               psl_files => \@alignment_files,
                                                               output_files => \@aligner_output_files,
                                                               psl_path => $self->build->merged_alignments_file,
                                                               blat_output_path => $self->build->merged_aligner_output_file,
                                                           );
    unless ($cat_blat_tool){
        $self->error_message('Failed to creaet tool to cat all blat alignments and aligner output');
        return;
    }
    unless ($cat_blat_tool->execute) {
        $self->error_message('Failed to execute command'. $cat_blat_tool->command_name);
        return;
    }

# Merge the sff files
    my $sfffile_tool = Genome::Model::Tools::454::Sfffile->create(
                                                                  in_sff_files => \@sff_files,
                                                                  out_sff_file => $self->build->merged_sff_file,
                                                         );
    unless ($sfffile_tool) {
        $self->error_message('Failed to create tool to merge sff files');
        return;
    }
    unless ($sfffile_tool->execute) {
        $self->error_message('Failed to execute command '. $sfffile_tool->command_name);
        return;
    }

    for my $dir ($self->build->merged_fasta_dir, $self->build->merged_qual_dir) {
        unless (-e $dir) {
            unless ($self->create_directory($dir)) {
                $self->error_message('Failed to create directory '. $dir);
                return;
            }
        }
    }

    my $sff_file = $self->build->merged_sff_file;
    my $fasta_convert = Genome::Model::Tools::454::Sffinfo->create(
                                                                   sff_file => $sff_file,
                                                                   output_file => $self->build->merged_fasta_file,
                                                                   params => '-s',
                                                               );
    unless ($fasta_convert) {
        $self->error_message('Could not create sffinfo tool for converting to fasta');
        return;
    }
    unless ($fasta_convert->execute) {
        $self->error_message('Failed to execute command '. $fasta_convert->command_name);
        return;
    }

    my $qual_convert = Genome::Model::Tools::454::Sffinfo->create(
                                                                   sff_file => $sff_file,
                                                                   output_file => $self->build->merged_qual_file,
                                                                   params => '-q',
                                                               );
    unless ($qual_convert) {
        $self->error_message('Could not create sffinfo tool for converting to fasta');
        return;
    }
    unless ($qual_convert->execute) {
        $self->error_message('Failed to execute command '. $qual_convert->command_name);
        return;
    }

    my $bio_db_convert = Genome::Model::Tools::BioDbFasta::Convert->create(
                                                                           infile => $self->build->merged_qual_file,
                                                                           outfile => $self->build->bio_db_qual_file,
                                                                       );
    unless ($bio_db_convert) {
        $self->error_message('Could not create BioDbFasta quality conversion tool');
        return;
    }
    unless ($bio_db_convert->execute) {
        $self->error_message('Failed to execute command '. $bio_db_convert->command_name);
        return;
    }
    my $bio_db_build_fasta = Genome::Model::Tools::BioDbFasta::Build->create(dir => $self->build->merged_fasta_dir);
    unless ($bio_db_build_fasta) {
        $self->error_message('Could not create BioDbFasta build tool for fasta dir');
        return;
    }
    unless ($bio_db_build_fasta->execute) {
        $self->error_message('Failed to execute command '. $bio_db_build_fasta->command_name);
        return;
    }
    my $bio_db_build_qual = Genome::Model::Tools::BioDbFasta::Build->create(dir => $self->build->merged_qual_dir);
    unless ($bio_db_build_qual) {
        $self->error_message('Could not create BioDbFasta build tool for qual dir');
        return;
    }
    unless ($bio_db_build_qual->execute) {
        $self->error_message('Failed to execute command '. $bio_db_build_qual->command_name);
        return;
    }
    my $blat_parser = Genome::Model::Tools::Blat::ParseAlignments->create(alignments_file => $self->build->merged_alignments_file);
    unless ($blat_parser) {
        $self->error_message('Could not create blat parser tool');
        return;
    }
    unless ($blat_parser->execute) {
        $self->error_message('Failed to execute command '. $blat_parser->command_name);
        return;
    }

    unless ($self->verify_successful_completion) {
        $self->error_message('Failed to verify_successful_completion');
        return;
    }

    $self->date_scheduled($start);
    $self->date_completed(UR::Time->now());
    $self->event_status('Succeeded');
    $self->event_type($self->command_name);
    $self->user_name($ENV{USER});

    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    unless (-s $self->build->merged_alignments_file) {
        $self->error_message('No merged alignments file: '. $self->build->merged_alignments_file);
        return;
    }
    unless (-s $self->build->merged_aligner_output_file) {
        $self->error_message('No merged aligner output file: '. $self->build->merged_aligner_output_file);
        return;
    }
    unless (-s $self->build->merged_fasta_file) {
        $self->error_message('No merged fasta sequence file: '. $self->build->merged_fasta_file);
        return;
    }
    unless (-s $self->build->merged_qual_file) {
        $self->error_message('No merged fasta quality file: '. $self->build->merged_qual_file);
        return;
    }
    unless (-s $self->build->bio_db_qual_file) {
        $self->error_message('No Bio::Db format quality file: '. $self->build->bio_db_qual_file);
        return;
    }
    unless (-d $self->build->merged_fasta_dir) {
        $self->error_message('No Bio::Db fasta directory: '. $self->build->merged_fasta_dir);
        return;
    }
    unless (-d $self->build->merged_qual_dir) {
        $self->error_message('No Bio::Db qual directory: '. $self->build->merged_qual_dir);
        return;
    }
    return 1;
}

1;

