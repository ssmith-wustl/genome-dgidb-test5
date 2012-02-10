package Genome::Model::Tools::Dindel::RunWithVcf;

use strict;
use warnings;

use Genome;
use Workflow;
use Workflow::Simple;

class Genome::Model::Tools::Dindel::RunWithVcf {
    is => 'Command',
    has => [
    input_vcf=> {
        is=>'String',
        is_input=>1,
    },
    output_directory=>{
        is=>'String',
        is_input=>1,
    },
    model_id => {
        is=>'String',
        is_input=>1,
    },
    num_windows_per_file=> {
        is=>'Number',
        is_input=>1,
        is_optional=>1,
        default=>'5000',
        doc=>'attempt to control the parallelization of dindel by setting max chunk size.'
    },
    ],
};

sub help_brief {
    'Run getCIGARindels'
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}


sub execute {
    my $self = shift;
    my $model = Genome::Model->get($self->model_id);
    my $bam_file = $model->last_succeeded_build->whole_rmdup_bam_file();
    my $ref_fasta = $model->reference_sequence_build->full_consensus_path("fa");
    unless($bam_file) {
        $self->error_message("Do you even have a succeeded build? There's no bam file! What did you do wrong this time?");
        return 0;
    }
    unless(-d $self->output_directory) {
        Genome::Sys->create_directory($self->output_directory);
    }

    $DB::single=1;
    my $vcf_in_dindel_format = $self->convert_vcf_to_dindel_and_left_shift($self->output_directory, $ref_fasta, $self->input_vcf);
    my @windows_files = $self->make_windows($self->output_directory, $vcf_in_dindel_format, $self->num_windows_per_file);
#    my $library_file = $self->get_cigar_indels($self->output_directory, $ref_fasta, $bam_file);
    my $library_file = "/gscmnt/gc2146/info/medseq/dindel/test_pipeline_version/cigar_generated_indels.libraries.txt";
    my $results_dir = $self->run_parallel_analysis($self->output_directory, $ref_fasta, $bam_file, $library_file, \@windows_files);
    my $file_of_results = $self->make_fof($self->output_directory, $results_dir);
    $self->generate_final_vcf($self->output_directory, $file_of_results, $ref_fasta);
    return 1;
}


sub generate_final_vcf {
    my ($self, $output_dir, $file_of_results, $ref_fasta) = @_;
    my $output_vcf = $output_dir . "/final_result.vcf";
    my $merger = Genome::Model::Tools::Dindel::MergeDindelOutput->create(
        dindel_file_output_list=>$file_of_results,
        output_file=>$output_vcf,
        ref_fasta=>$ref_fasta,
    );
    $merger->execute();
}

sub make_fof {
    my ($self, $output_dir, $results_dir) = @_;
    my $fof = $output_dir . "/file_of_result_files";
    my $fof_fh = IO::File->new($fof, ">");
    my @files = glob("$results_dir/*");
    for my $file (@files) {
        $fof_fh->print($file ."\n");
    }
    $fof_fh->close;
    return $fof;
}

sub run_parallel_analysis {
    my ($self, $output_dir, $ref_fasta, $bam_file, $library_file, $window_files) = @_;
    my $results_dir = $output_dir . "/results/";
    $DB::single=1;
    unless(-d $results_dir) {
        Genome::Sys->create_directory($results_dir);
    }
    my %inputs;
    $inputs{bam_file}=$bam_file;
    $inputs{ref_fasta}=$ref_fasta;
    $inputs{library_metrics_file}=$library_file;
    my @inputs;
    my @prefixes;
    for my $window (@$window_files) {
        $DB::single=1;
        my ($number) = ($window =~m/(\d+)\.txt/);
        push @inputs, "window_file_$number";
        push @inputs, "result_prefix_$number";
        $inputs{"window_file_$number"}= $window;
        $inputs{"result_prefix_$number"}= $results_dir . "/result_$number";
    }
    my $workflow = Workflow::Model->create(
        name=>"highly parallel dindel :-(",
        input_properties=> [
        'bam_file',
        'ref_fasta',
        'library_metrics_file',
        @inputs,
        ],
        output_properties=> [
        'output',
        ],
    );
    $workflow->log_dir($output_dir);
    for my $window (@$window_files) {
        my ($number) = ($window =~m/(\d+)\.txt/);

        my $analyze_op = $workflow->add_operation(
            name=>"dindel analyze window $number",
            operation_type=>Workflow::OperationType::Command->get("Genome::Model::Tools::Dindel::AnalyzeWindowFile"),
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"bam_file",
            right_operation=>$analyze_op,
            right_property=>"bam_file",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"ref_fasta",
            right_operation=>$analyze_op,
            right_property=>"ref_fasta",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"library_metrics_file",
            right_operation=>$analyze_op,
            right_property=>"library_metrics_file",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"window_file_$number",
            right_operation=>$analyze_op,
            right_property=>"window_file",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"result_prefix_$number",
            right_operation=>$analyze_op,
            right_property=>"output_prefix",
        );
        $workflow->add_link(
            left_operation=>$analyze_op,
            left_property=>"output_prefix",
            right_operation=>$workflow->get_output_connector,
            right_property=>"output",
        );
    }
    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }   
    $self->status_message("Now launching a butt-ton of dindel jobs");
    $DB::single=1;
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);
    unless($result) {
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("parallel mpileup workflow did not return correctly.");
    } 
    return $results_dir; 
} 

sub make_windows {
    my ($self, $output_dir, $candidate_indel_file, $num_windows) =@_;
    my $window_dir = $output_dir . "/windows/";
    unless(-d $window_dir) {
        Genome::Sys->create_directory($window_dir);
    }
    my $window_prefix = $window_dir ."/dindel_window_file";
    my $make_dindel_windows = Genome::Model::Tools::Dindel::MakeDindelWindows->create(
        input_dindel_file=>$candidate_indel_file,
        output_prefix=>$window_prefix,
        num_windows_per_file=>$num_windows,
    );
    if($make_dindel_windows->execute()) {
        return glob("$window_prefix*");
    }
    else {
        $self->error_message("Dindel Window maker failed for some reason. Exiting.");
        die;
    }
}

sub get_cigar_indels {
    my ($self, $output_dir, $ref_fasta, $bam_file) = @_;
    my $output_prefix = $output_dir . "/cigar_generated_indels";
    my $get_cigar_indels = Genome::Model::Tools::Dindel::GetCigarIndels->create(
        input_bam=>$bam_file,
        output_prefix=>$output_prefix,
        ref_fasta=>$ref_fasta
    );
    if($get_cigar_indels->execute()) {
        return $output_prefix . ".libraries.txt";
    }
    else {
        $self->error_message("fail from GetCigarIndels...exiting");
        die;
    }
}

sub convert_vcf_to_dindel_and_left_shift {
    my ($self, $output_dir, $ref_fasta, $input_vcf) = @_;
    my $output_dindel_file = $output_dir ."/dindel_formatted_vcf_input";
    my $vcf_to_dindel = Genome::Model::Tools::Dindel::VcfToDindel->create(
        input_vcf=> $input_vcf,
        output_dindel_file=>$output_dindel_file,
        ref_fasta=>$ref_fasta
    );
    $vcf_to_dindel->execute();
    my $left_shifted_output = $output_dindel_file . ".left_shifted";
    my $left_shifter = Genome::Model::Tools::Dindel::RealignCandidates->create( 
        ref_fasta=>$ref_fasta,
        variant_file=>$output_dindel_file,
        output_file=>$left_shifted_output,
    );
    if($left_shifter->execute()) {
        return $left_shifted_output . ".variants.txt";
    }
    else {
        $self->error_message("the left shifter has caused the datacenter to burn to the ground. great job. was it worth not getting those indels?");
        die;
    }
}
1;
