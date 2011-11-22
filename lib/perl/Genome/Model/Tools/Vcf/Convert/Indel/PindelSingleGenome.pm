package Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;
use Workflow;
use Workflow::Simple;
use File::Basename;

class Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome {
    is =>  'Genome::Model::Tools::Vcf::Convert::Base' ,
    doc => 'Generate a VCF file from varscan output',
    has => [
        _refseq => {
            is => 'Text',
            calculate_from => ['reference_sequence_input'],
            calculate => q| $reference_sequence_input |,
        },
    ],
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from pindel indel output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the indels.
HELP
}

sub source {
    my $self = shift;
    return "Pindel";
}

sub execute {
    my $self = shift;
    my $output = $self->output_file;
    my $pindel_raw = $self->input_file;
    my $refbuild_id = $self->reference_sequence_build->id;

    my ($output_directory) = dirname($output);
    $self->status_message("Output Directory for pindel-single-genome vcf creation will be: ".$output_directory);

    my %inputs;
    $inputs{pindel_raw_output} = $pindel_raw;
    $inputs{output_file} = $output;
    $self->status_message("VCF conversion output will be at: ".$output);
    $inputs{reference_build_id} = $refbuild_id;

    #my $temp_dir = Genome::Sys->create_temp_file_path;

    my $workflow = Workflow::Model->create(
        name => 'Multi-Vcf Merge',
        input_properties => [
            'pindel_raw_output',
            'output_file',
            'reference_build_id',
        ],
        output_properties => [
            'output',
        ],
    );
    $workflow->log_dir($output_directory);

    my $pindel2vcf = $workflow->add_operation(
        name => "Pindel2Vcf",
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Pindel::RunPindel2Vcf"),
    );

    for my $prop_name ("pindel_raw_output","output_file","reference_build_id"){
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $prop_name,
            right_operation => $pindel2vcf,
            right_property => $prop_name,
        );
    }

    $workflow->add_link(
        left_operation => $pindel2vcf,
        left_property => "output_file",
        right_operation => $workflow->get_output_connector,
        right_property => "output",
    );

    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->status_message("Now launching the vcf-merge workflow.");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

=cut

    #FIXME   this is all hardcoded, these need to be filled dynamically
    my $pindel2vcf_path = "/gscmnt/ams1158/info/pindel/pindel2vcf/pindel2vcf";
    my $refseq = $self->_refseq;
    my $rs = $self->reference_sequence_build; 
    my $refseq_name = $rs->name;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $date = $year . "/" . ($mon+1) . "/" . $mday . "-" . $hour . ":" . $min . ":" . $sec;
    my $pindel_raw = $self->input_file;
    my $output = $self->output_file;
    my $cmd  = $pindel2vcf_path . " -p ".$pindel_raw." -r ". $refseq . " -R " . $refseq_name . " -d " . $date . " -v " . $output; 
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    unless($result){
        die $self->error_message("Could not complete pindel2vcf run: ".$result);
    }
    my $bgzip_cmd = "bgzip -c ".$output." > ".$output.".tmp";
    $result = Genome::Sys->shellcmd( cmd => $bgzip_cmd );
    unless($result){
        die $self->error_message("Could not complete bgzip of output: ".$result);
    }
    unlink($output);
    $result = Genome::Sys->copy_file($output.".tmp",$output);
    unless($result){
        die $self->error_message("Could not move tmp zipped output to final output_file location: ".$result);
    }
    unlink($output.".tmp"); 
=cut
    return 1;
}

