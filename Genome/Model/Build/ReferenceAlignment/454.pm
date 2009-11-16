package Genome::Model::Build::ReferenceAlignment::454;


#REVIEW fdu
#Looks ok to me except for a little duplication samell of accumulated_alignments_directory.
#This can be refactored with less codes, like setting a generic method
#merge_file to return $self->accumulated_alignments_directory .'/'. $self->model->id . $file_suffix.


use strict;
use warnings;

use Genome;

class Genome::Model::Build::ReferenceAlignment::454 {
    is => 'Genome::Model::Build::ReferenceAlignment',
    has => [],
 };

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $model = $self->model;

    my @instrument_data = $model->instrument_data;

    unless (scalar(@instrument_data) && ref($instrument_data[0])  &&  $instrument_data[0]->isa('Genome::InstrumentData::454')) {
        $self->error_message('No instrument data has been added to model: '. $model->name);
        $self->error_message("The following command will add all available instrument data:\ngenome model add-reads --model-id=".
        $model->id .' --all');
        $self->delete;
        return;
    }

    return $self;
}

sub amplicon_header_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/'. $self->model->id .'_amplicon_headers.txt';
}

sub merged_alignments_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/'. $self->model->id .'.psl';
}

sub merged_aligner_output_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/'. $self->model->id .'.out';
}

sub merged_sff_file {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/'. $self->model->id .'.sff';
}

sub merged_fasta_dir {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/fasta_dir';
}

sub merged_fasta_file {
    my $self = shift;
    return $self->merged_fasta_dir .'/'. $self->model->id .'.fasta';
}

sub merged_qual_file {
    my $self = shift;
    return $self->merged_fasta_dir .'/'. $self->model->id .'.fasta.qual';
}

sub merged_qual_dir {
    my $self = shift;
    return $self->accumulated_alignments_directory .'/qual_dir';
}

sub bio_db_qual_file {
    my $self = shift;
    return $self->merged_qual_dir .'/'. $self->model->id .'.qual.fa';
}


1;

