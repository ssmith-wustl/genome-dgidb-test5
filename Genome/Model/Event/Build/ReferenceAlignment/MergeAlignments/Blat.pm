package Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments::Blat;

#REVIEW fdu 11/19/2009
#Move codes of if block dealing with BreakPointRead to
#G::M::C::B::R::F::BreakPointRead

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments::Blat {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments'],
};

sub should_bsub {
    die "should_bsub is deprecated";
}

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
    my @idas = $model->instrument_data_assignments;
    unless (scalar(@idas)) {
        $self->error_message('No instrument data assignments found for model '. $model->id );
        return;
    }
    my @alignment_files;
    my @aligner_output_files;
    my @fasta_files;
    my @qual_files;
    my $build = $self->build;
    for my $instrument_data_assignment (@idas) {
        my $alignment = $instrument_data_assignment->results;
        my $alignment_file = $alignment->alignment_file;
        unless ($alignment_file) {
            $self->error_message('Failed to find alignment_file.');
            return;
        }
        push @alignment_files, $alignment_file;

        my $aligner_output_file = $alignment->aligner_output_file;
        unless ($aligner_output_file) {
            $self->error_message('Failed to find aligner_output_file.');
            return;
        }
        push @aligner_output_files, $aligner_output_file;
        my $instrument_data = $instrument_data_assignment->instrument_data;
        push @fasta_files, $instrument_data->fasta_file;
        push @qual_files, $instrument_data->qual_file;
    }

    # Merge the blat alignments and aligner output
    unless (-s $self->build->merged_alignments_file && -s $self->build->merged_aligner_output_file) {
        $self->status_message('Merging the blat output.'); 
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
    } else {
        $self->status_message('shortcutting the blat output merge');
    }

    for my $dir ($self->build->merged_fasta_dir, $self->build->merged_qual_dir) {
        unless (-e $dir) {
            unless ($self->create_directory($dir)) {
                $self->error_message('Failed to create directory '. $dir);
                return;
            }
        }
    }

    unless (-s $self->build->merged_fasta_file) {
        $self->status_message('Merging fasta files.');
        $self->cat(
                   input_files => \@fasta_files,
                   output_file => $self->build->merged_fasta_file
               );
    } else {
        $self->status_message('shortcutting the merge of fasta files');
    }

    unless (-s $self->build->merged_qual_file) {
        $self->status_message('Merging qual files.');
        $self->cat(
                   input_files => \@qual_files,
                   output_file => $self->build->merged_qual_file
               );
    } else {
        $self->status_message('shortcutting the merge of qual files');
    }
    #TODO: Move this to FindVariation::BreakPointRead
    if ($self->model->indel_finder_name eq 'breakPointRead') {
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
    unless (-d $self->build->merged_fasta_dir) {
        $self->error_message('No fasta directory: '. $self->build->merged_fasta_dir);
        return;
    }
    unless (-d $self->build->merged_qual_dir) {
        $self->error_message('No qual directory: '. $self->build->merged_qual_dir);
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
    #TODO: Move this to FindVariations::BreakPointRead
    if ($self->model->indel_finder_name eq 'breakPointRead') {
        unless (-s $self->build->bio_db_qual_file) {
            $self->error_message('No Bio::Db format quality file: '. $self->build->bio_db_qual_file);
            return;
        }
    }

    return 1;
}

1;

