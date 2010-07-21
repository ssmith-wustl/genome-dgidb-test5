package Genome::Model::Tools::Convergence::Pipeline;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Convergence::Pipeline {
    is          => ['Workflow::Operation::Command'],
    workflow    => sub { Workflow::Operation->create_from_xml(\*DATA); },
};

sub help_brief {
    "Runs the harmonic-convergence pipeline workflow."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
gmt convergence pipeline --build-id 8 --data-directory /some/dir/for/data
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the harmonic convergence pipeline.
EOS
}

sub pre_execute {
    my $self = shift;
    
    my $build_id = $self->build_id;
    
    my $build = Genome::Model::Build->get($build_id);
    
    unless($build) {
        $self->error_message('Build not found for ID ' . $build_id);
        return;
    }
    
    my @members = $build->members;
    
    #Check that the members are ready for convergence
    for my $member (@members) {
         unless($member->status eq 'Succeeded') {
            $self->error_message("Tried to use non-succeeded build! " . $member->id);
            return;
        }
    } 

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        return;
    }
    
    #Assign filenames
    my %default_filenames = $self->default_filenames;
    for my $parameter (keys %default_filenames) {
        $self->$parameter($data_directory . "/" . $default_filenames{$parameter});
    }
    
    unless(defined $self->skip_if_output_present) {
        $self->skip_if_output_present(1);
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
    );

    return %default_filenames;
}

1;

__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Harmonic Convergence Pipeline" logDir="/gsc/var/log/genome/harmonic_convergence_pipeline">

  <link fromOperation="input connector" fromProperty="build_id" toOperation="Generate Report" toProperty="build_id" />

  <link fromOperation="Generate Report" fromProperty="_summary_report" toOperation="output connector" toProperty="_summary_report" />

  <operation name="Generate Report">
    <operationtype commandClass="Genome::Model::Tools::Convergence::SummaryReport" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>build_id</inputproperty>
    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>

    <outputproperty>_summary_report</outputproperty>
  </operationtype>

</workflow>
