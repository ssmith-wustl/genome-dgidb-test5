package Genome::Model::Build::RnaSeq::Solexa;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::RnaSeq::Solexa {
    is => 'Genome::Model::Build::RnaSeq',
    has => [],

};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self) {
        return;
    }

    my $model = $self->model;

    my @instrument_data = $model->instrument_data;
    unless (@instrument_data) {
        $self->error_message('No instrument data have been added to model: '. $model->name);
        $self->error_message("The following command will add all available instrument data:\ngenome model instrument-data assign  --model-id=".
        $model->id .' --all');
        return;
    }

    return $self;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    #most space is allocated from within the alignment result
    return 10_240_000;
}

sub log_directory {
    my $self = shift;
    return $self->data_directory .'/logs/';
}

sub dedup_metrics_file {
    my $self = shift;
    return $self->log_directory .'/mark_duplicates.metrics';
}

sub rmdup_metrics_file {
    my $self = shift;
    return $self->dedup_metrics_file;
}

sub dedup_log_file {
    my $self = shift;
    return $self->log_directory .'/mark_duplicates.log';
}

sub rmdup_log_file {
    my $self = shift;
    return $self->dedup_log_file;
}

sub whole_rmdup_bam_file {
    my $self = shift;
    return $self->dedup_bam_file;
}

sub dedup_bam_file {
    my $self = shift;

    my @files = glob($self->accumulated_alignments_directory .'/*_dedup.bam');

    if (@files > 1) {
        my @not_symlinks;
        my @symlinks;
        for (@files) {
            if (-l $_) {
                push @symlinks, $_;
            }
            else {
                push @not_symlinks, $_;
            }
        }
        if (@not_symlinks == 1) {
            $self->warning_message("Found multiple files, but all but one are symlinks.  Selecting @not_symlinks.  Ignoring @symlinks.");
            return $not_symlinks[0];
        }
        else {
	        $self->error_message("Multiple merged rmdup bam file found.");
            return;
        }
    }
    elsif (@files == 0) {
	    return $self->accumulated_alignments_directory .'/'. $self->build_id .'_dedup.bam';
    }
    else {
    	return $files[0];
    }
}

sub alignment_stats_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/alignment_stats.txt';
}

sub merged_bam_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/all_reads_merged.bam';
}

sub generate_tcga_file_name {
    my $self = shift;
    my $model = $self->model;
    my $dna_id  = $model->subject_id;

    my $ex_species_name = GSC::DNAExternalName->get( dna_id => $dna_id, name_type => 'biospecimen id',);
    if ( !defined($ex_species_name) ) {
        $self->error_message("The external species name via the name type of 'biospecimen id' is not defined for this model.  Cannot generate a TCGA file name.");
        return;
    }

    my $ex_plate_name = GSC::DNAExternalName->get( dna_id => $dna_id, name_type => 'plate id',);
    if ( !defined($ex_plate_name) ) {
        $self->error_message("The external plate name via the name type of 'palate id' is not defined for this model.  Cannot generate a TCGA file name.");
        return;
    }

    return $ex_species_name->name .'-'. $ex_plate_name->name .'-09'; 
}


1;

