package Genome::ProcessingProfile::ReferenceAlignment::Solexa;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ReferenceAlignment::Solexa {
    is => 'Genome::ProcessingProfile::ReferenceAlignment',
};
sub stages {
    my @stages = qw/

        alignment
        deduplication
        variant_detection
        generate_reports
        verify_successful_completion
    /;
    return @stages;
}

sub alignment_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::ReferenceAlignment::AssignRun
        Genome::Model::Command::Build::ReferenceAlignment::AlignReads
        Genome::Model::Command::Build::ReferenceAlignment::ProcessLowQualityAlignments
    /;
    return @sub_command_classes;
}


sub variant_detection_job_classes {
    my @steps = (
                 'Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype',
                 'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
                 (
                  'Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations',
                  'Genome::Model::Command::Build::ReferenceAlignment::AnnotateVariations'
              )
             );

    return @steps;
}

sub deduplication_job_classes {
    my @steps = ( 
        'Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries'
    );
    return @steps;
}

sub generate_reports_job_classes {
    my @steps = (
        'Genome::Model::Command::Build::ReferenceAlignment::RunReports'
    );
    return @steps;
}


sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub alignment_objects {
    my $self = shift;
    my $model = shift;
    return $model->unbuilt_read_sets;
}

   

sub variant_detection_objects {
    my $self = shift;
    my $model = shift;
    my @subreferences_names = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    unless (@subreferences_names > 0) {
        @subreferences_names = ('all_sequences');
    }
    return @subreferences_names;
}

sub deduplication_objects {
    my $self = shift;
    my $model = shift;
    my @subreferences_names = grep {$_ eq "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');
   
   return @subreferences_names;
}

sub generate_reports_objects {
    my $self = shift;
    my $model = shift;
    my @subreferences_names = grep {$_ eq "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');
   
   return @subreferences_names;
}


sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
    $self->model->current_running_build_id($self->id);
}
1;

