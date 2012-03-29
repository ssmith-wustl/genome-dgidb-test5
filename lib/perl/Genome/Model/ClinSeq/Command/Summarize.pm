package Genome::Model::ClinSeq::Command::Summarize;
use strict;
use warnings;
use Genome;
use Data::Dumper;

class Genome::Model::ClinSeq::Command::Summarize {
    is => 'Command::V2',
    has_input => [
        models => { 
            is => 'Genome::Model::ClinSeq',
            is_many => 1,
            shell_args_position => 1,
            require_user_verify => 0,
            doc => 'clinseq models to sumamrize'
        },
    ],
    doc => 'summarize clinseq model status and results',
};

sub help_synopsis {
    return <<EOS

genome model clin-seq summarize 12345

genome model clin-seq summarize mymodelname

genome model clin-seq summarize subject.common_name=HG1

genome model clin-seq summarize subject.common_name=HG%

EOS
}

sub help_detail {
    return <<EOS
Summarize the status and key metrics for 1 or more clinseq models.

(put more content here)
EOS
}

sub execute {
  my $self = shift;
  my @models = $self->models;
    
  for my $model (@models) {
    $self->status_message("\n***** " . $model->__display_name__ . " ****");
    $self->status_message("\n\nSamples and instrument data");

    my $patient = $model->subject;
    my @samples = $patient->samples;
    for my $sample (@samples) {
      my @instdata = $sample->instrument_data;
      my $scn = $sample->common_name;
      my $tissue_desc = $sample->tissue_desc;
      my $extraction_type = $sample->extraction_type;
      $self->status_message("sample " . $sample->__display_name__ . " ($tissue_desc - $extraction_type) has " . scalar(@instdata) . " instrument data");
    }

    #Check for a complete build of the clinseq model specified
    my $clinseq_build = $model->last_complete_build;
    unless ($clinseq_build) {
      $self->status_message("NO COMPLETE CLINSEQ BUILD!");
      next;
    }

    #Summarize the build IDs and status of each build comprising the ClinSeq model
    $self->status_message("\n\nBuilds and status of each");
    my $wgs_build = $clinseq_build->wgs_build;
    my $exome_build = $clinseq_build->exome_build;
    my $tumor_rnaseq_build = $clinseq_build->tumor_rnaseq_build;
    my $normal_rnaseq_build = $clinseq_build->normal_rnaseq_build;
    my @builds = ($wgs_build, $exome_build, $tumor_rnaseq_build, $normal_rnaseq_build, $clinseq_build);
    for my $build (@builds) {
      next unless $build;
      $self->status_message("build '" . $build->__display_name__ . "' has status " . $build->status);
    }
   
    $self->status_message("\n\nProcessing profiles associated with each model"); 
    for my $build (@builds){
      next unless $build;
      my $m = $build->model;
      my $pp_id = $m->processing_profile_id;
      my $pp = Genome::ProcessingProfile->get($pp_id);
      my $pp_type = $pp->type_name;
      my $pp_name = $pp->name;
      $self->status_message("model '" . $m->id . "' used processing profile '" . $pp->__display_name__ . "' ($pp_type)");
    }

    $self->status_message("\n\nReference sequence build associated with each model");
    for my $build (@builds){
      next unless $build;
      my $m = $build->model;
      if ($m->can("reference_sequence")){
        my $rb = $m->reference_sequence;
        $self->status_message("model '" . $m->id . "' used reference build '" . $rb->__display_name__);
      }

    }   


    $self->status_message("\n\nInstrument data actually used by each build");
    for my $build (@builds){
       next unless $build;
       my @instdata = $build->instrument_data;
       $self->status_message("build " . $build->__display_name__ . " uses " . scalar(@instdata) . " instrument data");
    }


  }

  $self->status_message("\n\n");

  return 1;
}

1;

