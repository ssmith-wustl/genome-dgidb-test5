package Genome::Model::Tools::Rna::ModelGroupFpkmMatrix;

use strict;
use warnings;

use Genome;
use Statistics::Descriptive;

class Genome::Model::Tools::Rna::ModelGroupFpkmMatrix {
    is => 'Genome::Command::Base',
    has => [
        model_group => {
            is => 'Genome::ModelGroup',
            shell_args_position => 1,
            doc => 'Model group of RNAseq models to generate expression matrix.',
        },
        fpkm_tsv_file => {
            doc => 'The output tsv file of genes passing the CV filter with FPKMvalues per sample.',
        },
    ],
    has_optional => [
    ],

};

sub help_synopsis {
    return <<"EOS"
    gmt rna model-group-fpkm-matrix --model-group 2
EOS
}

sub help_brief {
    return "Accumulate RNAseq FPKM values into a matrix.";
}

sub help_detail {
    return <<EOS
Accumulate FPKM values for genes across all samples for an RNAseq model-group.
EOS
}


sub execute {
    my $self = shift;
    my @models = $self->model_group->models;
    my @non_rna_models = grep { !$_->isa('Genome::Model::RnaSeq') } @models;
    if (@non_rna_models) {
        die('Found a non-RNAseq model: '. Data::Dumper::Dumper(@non_rna_models));
    }
    my @builds;
    my $annotation_build;
    my $reference_build;
    my %subjects;
    for my $model (@models) {
        if ( defined($subjects{$model->name}) ) {
            die('Multiple models for subject: '. $model->name);
        } else {
            $subjects{$model->name} = 1;
        }
        my $build = $model->last_succeeded_build;
        unless ($build) {
            $build = $model->latest_build;
            unless ($build) {
                die('Failed to find build for model: '. $model->id);
            }
        }
        push @builds, $build;
        my $model_reference_sequence_build = $model->reference_sequence_build;
        if ($reference_build) {
            unless ($reference_build->id eq $model_reference_sequence_build->id) {
                die('Mis-match reference sequence builds!');
            }
        } else {
            $reference_build = $model_reference_sequence_build;
        }
        my $model_annotation_build = $model->annotation_build;
        if ($annotation_build) {
            unless ($annotation_build->id eq $model_annotation_build->id) {
                die('Mis-match annotation builds!');
            }
        } else {
            $annotation_build = $model_annotation_build;
        }
    }
    my @subjects = sort keys %subjects;
    my @headers = ('gene_id',@subjects);
    my $tsv_writer = Genome::Utility::IO::SeparatedValueWriter->create(
        output => $self->fpkm_tsv_file,
        separator => "\t",
        headers => \@headers,
    );
    my $gtf_path = $annotation_build->annotation_file('gtf',$reference_build->id);
    my $gff_reader = Genome::Utility::IO::GffReader->create(
        input => $gtf_path,
    );
    unless ($gff_reader) {
        die('Failed to read GTF file: '. $gtf_path);
    }
    my %genes;
    while (my $data = $gff_reader->next_with_attributes_hash_ref) {
        my $attributes = delete($data->{attributes_hash_ref});
        $genes{$attributes->{gene_id}}{gene_id} = $attributes->{gene_id};
    }
    $self->status_message('There are '. scalar(keys %genes) .' genes in annotation file: '. $gtf_path);
    for my $build (@builds) {
        my $gene_fpkm_tracking = $build->data_directory .'/expression/genes.fpkm_tracking';
        unless (-e $gene_fpkm_tracking) {
            die ('Failed to find gene FPKM file: '. $gene_fpkm_tracking);
        }
        my $gene_fpkm_reader = Genome::Utility::IO::SeparatedValueReader->create(
            input => $gene_fpkm_tracking,
            separator => "\t",
        );
        my $match = 0;
        while (my $fpkm_data = $gene_fpkm_reader->next) {
            if ( defined($genes{$fpkm_data->{gene_id}}) ) {
                if ( defined($genes{$fpkm_data->{gene_id}}{$build->model->name}) ) {
                    if ($genes{$fpkm_data->{gene_id}}{$build->model->name} < $fpkm_data->{FPKM}) {
                        $genes{$fpkm_data->{gene_id}}{$build->model->name} = $fpkm_data->{FPKM};
                    }
                } else {
                    $genes{$fpkm_data->{gene_id}}{$build->model->name} = $fpkm_data->{FPKM};
                    $match++;
                }
            }
        }
        $self->status_message('There are '. $match .' matching genes in FPKM file: '. $gene_fpkm_tracking);
    }
    for my $gene (sort keys %genes) {
        my %data = %{$genes{$gene}};
        # Depending on the mode cufflinks was run, there may not be an entry for all genes in every FPKM file,  stick to reference only mode
        if (scalar(keys %data) == (scalar(@headers))) {
            my @values = map { $data{$_} } @subjects;
            my $stat = Statistics::Descriptive::Sparse->new();
            $stat->add_data(@values);
        } else {
            #is there a minimum number of samples(90%) that is required....
        }
    }
    for my $gene (sort keys %genes) {
        my %data = %{$genes{$gene}};
        # Depending on the mode cufflinks was run, there may not be an entry for all genes in every FPKM file,  stick to reference only mode
        if (scalar(keys %data) == (scalar(@headers))) {
            $tsv_writer->write_one(\%data);
        }
    }
    return 1;
}
