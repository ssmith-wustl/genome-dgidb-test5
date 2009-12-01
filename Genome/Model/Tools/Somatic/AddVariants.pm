# review tmooney
# This tool uses Genome::VariantOccurrence, but should either use Genome::Model::Variant or be removed.


package Genome::Model::Tools::Somatic::AddVariants;

use strict;
use warnings;
use Genome;
use Genome::Utility::HugoGene::HugoGeneMethods;
use Carp;

class Genome::Model::Tools::Somatic::AddVariants{
    is => 'Command',
    has => [
    input_file => {
        is  => 'String',
        doc => 'The input file of variants to be stored. this should be in annotation input format, which is: chr start stop ref var',
    },
    model_search_string => {
        is_optional=>1,
        doc => 'The string to try to resolve a model id from. untested but works in theory',
    },
    model_id => {
        is_optional=>1,
        doc =>"The model you want to add variants to. if supplied, simply adds them all to latest build id",
    },
    build_id => {
        is_optional=>1,
        doc=>"the build id to add variants to supply only one of the above",
    }


    ],
};

sub help_brief {
    "adds any known variants to the database",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    genome-model tools somatic add-variants...    
EOS
}

sub help_detail {                           
    return <<EOS 
    adds somatic variants to db
EOS
}

sub execute {
    my $self = shift;
    my $build_id = $self->resolve_build_id;
    unless($build_id) {
        $self->error_message("Unable to resolve build id!");
        return;
    }
    my $ifh=IO::File->new($self->input_file);

    my $annotator = Genome::Model::Tools::Annotate::TranscriptVariantsStream->create(annotation_filter=>'top');

    while (my $line=$ifh->getline) {
        #assume  annotation input;
        chomp $line;
        my ($chr,
        $start_pos,
        $stop_pos,
        $ref,
        $var) = split /\t/, $line;

        $DB::single=1;
        my @transcripts = $annotator->annotate($chr,$start_pos,$stop_pos,$ref,$var);
        my $gene_name = $transcripts[0]->{gene_name};
        Genome::VariantOccurrence->create(
            build_id=> $build_id,
            chromosome=> $chr,
            start_pos => $start_pos,
            stop_pos => $stop_pos,
            reference_allele=>$ref,
            variant_allele=>$var,
            gene=> $gene_name,
            somatic_status => 'S',);
        }

    }

    sub resolve_build_id {
        my $self=shift;
        if($self->build_id) { 
            if(my $build = Genome::Model::Build->get($self->build_id)) {
                return $self->build_id;
            } else {return;}
        }elsif($self->model_id) {
            if(my $model=Genome::Model->get($self->model_id)) {
                if($model->last_complete_build_id) {
                    return $model->last_complete_build_id;
                }
                else{ return;}
            }
        }elsif($self->model_search_string) {
            my @models = Genome::Model->get(operator=>'like', value=>$self->model_search_string);
            if(scalar(@models) > 1) {
                $self->error_message("Search String inadequate: multiple models found");
                my @model_names = map { $_->name } @models;
                $self->error_message( join "\n", @model_names);
                return;
            }
            if(my $model=Genome::Model->get($models[0]->id)) {
                if($model->last_complete_build_id) {
                    return $model->last_complete_build_id;
                }
                else {
                    $self->error_message("couldn't resolve model from earch string"); 
                    return;
                }
            }
        }

    }

1;
