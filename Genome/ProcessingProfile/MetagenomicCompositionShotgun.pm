package Genome::ProcessingProfile::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MetagenomicCompositionShotgun {
    is => 'Genome::ProcessingProfile',
};

1;
__END__
    has_param => [
    #Human Contamination Screen
        contamination_screen_pp => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            id_by => 'human_contamination_pp_id',
            doc => 'processing profile to use for human contamination screen stage',
        },
        metagenomic_alignment_pp => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            id_by => 'bacteria_pp_id',
            doc => 'processing profile to use for bacteria alignment in metagenomic stage',
        },
        merging_strategy => {
            is => 'Text',
            valid_values => [qw/ best_hit bwa /],
            doc => 'strategy used to merge results from metagenomic alignments. valid values : best_hit',
        }
    ],
sub _execute_build{
    my ($self, $build) = @_;

    my $model = $build->model;

    if (!$model){
        $self->error_message("Couldn't find model for build id");
        return;
    }

    my $hcs_model = $model->hcs_model;

    #ASSIGN ANY NEW ID TO UNDERLYING MODELS
    
    my @instrument_data = $model->inst_data;
    my %hcs_instrument_data = map { $_->id => $_ }$hcs_model->inst_data;
     
    my @to_add = grep {! $hcs_instrument_data{$_->id}} @hcs_instrument_data

    
    #TODO:put this logic in Genome::Model::assign_instrument_data() so we don't have to use a command
    for (@to_add){
        my $cmd = Genome::Model::Command::InstrumentData::Assign->create(
            model_id => $model->model_id,
            instrument_data_id => $_->id,
            }
        );
    }

    #BUILD HUMAN CONTAMINATION SCREEN MODEL

    my $hcs_model = $model->hcs_model;

    unless ($hcs_model){
        $self->error_message("couldn't grab human contamination screen underlying model!");
        return;
    }

    if ($self->need_to_build($hcs_model)){
        my $hcs_build = $self->run_ref_align_build($hcs_model);

        unless ($hcs_build){
            $self->error_message("Couldn't create human contamination screen build!");
        }

        
    }

    #IMPORT INSTRUMENT DATA
    
    #ASSIGN IMPORTED INSTRUMENT DATA
    
    #RUN METAGENOMIC REF-ALIGN-BUILDS
    my @sub_models = ( $model->bacteria_model_1, 
                      $model->bacteria_model_2,
                      $model->viral_model,
                      $model->eukaryota_model,
                      $model->archaea_model);

    foreach my $sub_model (@sub_models)
    {
        my $sub_build = Genome::Model::Build->create(
            model_id => $sub_model->genome_model_id
        );

        unless ($sub_build){
            $self->error_message("Couldn't create build for underlying ref-align model " . $sub_model->name);
        }

        my $rv = $sub_build->start;

        if ($rv){
            $self->status_message("Created and started build for underlying ref-align model " .  $sub_model->name);
        }

        my $build_status = $sub_build->status;
        while ($sub_build_status eq 'Running'){
            sleep 60;
            $sub_build_status = $sub_build->status;
        }

        unless ($sub_build_status eq 'Succeeded'){
            $self->error_message($sub_model->name . " build did not complete successfully!  Build status: $build_status");
        }
    }
    
    #REPORTING
}


sub run_ref_align_build{
    my ($self, $model) = @_;

    my $sub_build = Genome::Model::Build->create(
        model_id => $model->genome_model_id
    );
    unless ($sub_build){
        $self->error_message("Couldn't create build for underlying ref-align model " . $model->name);
        return;
    }

    my $rv = $sub_build->start;

    if ($rv){
        $self->status_message("Created and started build for underlying ref-align model " .  $model->name);
    }
    return $sub_build;
}

sub wait_for_build{
    my ($self, $build) = @_;
}

sub need_to_build{
    my ($self, $build) = @_;
    return 1;
}

sub _resolve_disk_group_name_for_build {
    return 'info_apipe';    
}


1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/ProcessingProfile/MetagenomicComposition16s.pm $
#$Id: MetagenomicComposition16s.pm 56538 2010-03-15 23:42:35Z ebelter $
