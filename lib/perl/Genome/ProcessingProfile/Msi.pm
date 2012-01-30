package Genome::ProcessingProfile::Msi;
use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Msi {
    is => 'Genome::ProcessingProfile',
    doc => "manual sequence improvement",
    has => [
        percent_identity => {
            is => 'Number',
            default_value => 90,
            is_optional => 1,
            doc => 'the percentage of bases in the alignment region that are a match',
        },
        match_length => {
            is => 'Number',
            default_value => 200,
            is_optional => 1,
            doc => 'the length of the aligned region',
        },
    ],
};

#__END__
sub _execute_build {
    my ($self,$build) = @_;

    my $assembly_model = $build->model->from_models;

    my $assembly_build = $assembly_model->last_complete_build;
    unless ($assembly_build) {
        $self->error_message("Underlying model " . $assembly_model->__display_name__ . " has no complete builds!");
        return;
    }
    
    unless ($build->add_from_build(from_build => $assembly_build, role => 'imported assembly')) {
        Carp::confess("Failed link imported assembly build!");
    }
    
    my $assembly_build_directory = $assembly_build->data_directory;
    unless ($assembly_build_directory && -e $assembly_build_directory) {
        my $msg = $self->error_message("Failed to get last complete build directory for the input assembly!");
        Carp::confess($msg);
    }
    warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";
        
    my $percent_identity = $self->percent_identity||90;
    my $match_length = $self->match_length||200;
    
    warn "Detecting Merges....\n";
    $self->error_message("There was an error detecting merges") and return unless 
        Genome::Model::Msi::Command::DetectMerges->execute(assembly_build_id => $assembly_build->id);
    
    warn "Creating Merge List...\n";
    $self->error_message("There was an error creating the merge list") and return unless 
        Genome::Model::Msi::Command::CreateMergeList->execute(assembly_build_id => $assembly_build->id, percent_identity => $percent_identity, match_length => $match_length);
    
    warn "Merging Contigs...\n";
    $self->error_message("There was an error executing the merges") and return unless 
        Genome::Model::Msi::Command::DoMerges->execute(assembly_build_id => $assembly_build->id, output_build_id => $build->id);
    
    warn "Writing changes to Build Directory ",$build->data_directory,"\n";
    $self->error_message("There was an error writing the changes to the build directory") and return unless 
        Genome::Model::Msi::Command::WriteChangesToBuild->execute(assembly_build_id => $assembly_build->id, output_build_id => $build->id);
    
    return 1;
}

1;

