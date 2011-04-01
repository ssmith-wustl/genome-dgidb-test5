package Genome::Model::Tools::DetectVariants2::Pindel;

use warnings;
use strict;

use Genome;
use Workflow;
use File::Copy;
use Workflow::Simple;
use Cwd;

my $DEFAULT_VERSION = '0.2';
my $PINDEL_COMMAND = 'pindel_64';

class Genome::Model::Tools::DetectVariants2::Pindel {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    doc => "Runs the pindel pipeline on the last complete build of a somatic model.",
    has => [
        chromosome_list => {
            is => 'ARRAY',
            is_optional => 1,
            doc => 'list of chromosomes to run on.',
        },
        chr_mem_usage => {
            is => 'ARRAY',
            is_optional => 1,
            doc => 'list of mem to request per chromosomes to run on.',
        },
   ],
    has_constant_optional => [
        sv_params=>{},
        detect_svs=>{},
        snv_params=>{},
        detect_snvs=>{},
    ],
    has_transient_optional => [
        _workflow_result => {
            doc => 'Result of the workflow',
        },
        _indel_output_dir => {
            is => 'String',
            doc => 'The location of the indels.hq.bed file',
        },
        _chr_mem_usage => {
            doc => 'This is a hashref containing the amount of memory in MB to request for each chromosome job of pindel',
        },
    ],
    has_param => [
        lsf_queue => {
            default_value => 'workflow'
        },
    ],
};

my %CHR_MEM_USAGE = (
    '1' => 'Large',
    '2' => 'Large',
    '3' => 'Large',
    '4' => 'Medium',
    '5' => 'Medium',
    '6' => 'Medium',
    '7' => 'Medium',
    '8' => 'Medium',
    '9' => 'Medium',
    '10' => 'Medium',
    '11' => 'Medium',
    '12' => 'Medium',
    '13' => 'Regular',
    '14' => 'Regular',
    '15' => 'Regular',
    '16' => 'Regular',
    '17' => 'Regular',
    '18' => 'Regular',
    '19' => 'Regular',
    '20' => 'Regular',
    '21' => 'Regular',
    '22' => 'Regular',
    'X' => 'Regular',
    'Y' => 'Regular',
);

sub _detect_variants {
    my $self = shift;
    # Obtain normal and tumor bams and check them. Either from somatic model id or from direct specification. 
    my ($build, $tumor_bam, $normal_bam);
    $tumor_bam = $self->aligned_reads_input;
    $normal_bam = $self->control_aligned_reads_input if defined $self->control_aligned_reads_input;

    unless(defined($self->reference_sequence_input)){
        $self->reference_sequence_input( Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa' );
    }

    # Set default params
    unless ($self->chromosome_list) { 
        $self->chromosome_list([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,'X','Y']); 
    }
    unless ($self->indel_bed_output) { 
        $self->indel_bed_output($self->_temp_staging_directory. '/indels.hq.bed'); 
    }

    my %input;
    $input{reference_sequence_input}=$self->reference_sequence_input;
    $input{aligned_reads_input}=$self->aligned_reads_input;
    $input{control_aligned_reads_input}=$self->control_aligned_reads_input if defined $self->control_aligned_reads_input;
    $input{output_directory} = $self->output_directory;#$self->_temp_staging_directory;
    $input{version}=$self->version;
    
    for my $chr (@{$self->chromosome_list}){
        $input{"chr_$chr"}=$chr;
    }
    print Data::Dumper::Dumper(\%input);
    $self->status_message("Generating workflow now.");

    my $workflow = $self->generate_workflow;

    $self->_dump_workflow($workflow);

    my @errors = $workflow->validate;

    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->status_message("Launching workflow now.");

    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %input);
    unless($result){
        die $self->error_message("Workflow did not return correctly.");
    }
    $self->_workflow_result($result);

    return 1;
}

sub _dump_workflow {
    my $self = shift;
    my $workflow = shift;
    my $xml = $workflow->save_to_xml;
    my $xml_location = $self->output_directory."/workflow.xml";
    my $xml_file = Genome::Sys->open_file_for_writing($xml_location);
    print $xml_file $xml;
    $xml_file->close;
    #$workflow->as_png($self->output_directory."/workflow.png"); #currently commented out because blades do not all have the "dot" library to use graphviz
}

sub _create_temp_directories {
    my $self = shift;
    $self->_temp_staging_directory($self->output_directory);
    $self->_temp_scratch_directory($self->output_directory);
    return 1;

    return $self->SUPER::_create_temp_directories(@_);
}

sub _promote_staged_data {
    my $self = shift;
    my $staging_dir = $self->_temp_staging_directory;
    my $output_dir  = $self->output_directory;
    my @chrom_list = @{$self->chromosome_list};
    my $test_chrom = $chrom_list[0];
    my $bed = $self->output_directory."/".$test_chrom."/indels_all_sequences.bed";
    $bed = readlink($bed);
    my @stuff = split "\\.", $bed;
    my $bed_version = $stuff[-2];

    my $output_file = $output_dir."/indels.hq.".$bed_version.".bed";
    my @inputs = map { $output_dir."/".$_."/indels_all_sequences.bed" } @chrom_list;
    my $cat_cmd = Genome::Model::Tools::Cat->create( dest => $output_file, source => \@inputs);
    unless($cat_cmd->execute){
        $self->error_message("Cat command failed to execute.");
        die $self->error_message;
    }
    my $cwd = getcwd;
    chdir $output_dir;
    Genome::Sys->create_symlink("indels.hq.".$bed_version.".bed", "indels.hq.bed");
    chdir $cwd; 
    return 1;
}

sub _run_converter {
    my $self = shift;
    my $converter = shift;
    my $source = shift;
    
    my $output = $source . '.bed'; 
    
    my $command = $converter->create(
        source => $source,
        output => $output, 
        include_normal => 1,
    );
    
    unless($command->execute) {
        $self->error_message('Failed to convert ' . $source . ' to the standard format.');
        return;
    }

    return 1;
}

sub has_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::DetectVariants::Somatic::Pindel->available_pindel_versions;

    for my $v (@versions){
        if($v eq $version){
            return 1;
        }
    }

    return 0;
}



sub generate_workflow {
    my $self = shift;
    my @output_properties = map{ "Chr_".$_."_output" }  @{$self->chromosome_list};
    my @input_properties,  map { "chr_$_" } @{$self->chromosome_list};
    my $workflow_model = Workflow::Model->create(
        name => 'Parallel Pindel by Chromosome',
        input_properties => [
            'reference_sequence_input',
            'aligned_reads_input',
            'control_aligned_reads_input',
            'output_directory',
            'version',
            @input_properties,
        ],
        output_properties => [
            @output_properties,
        ],
    
    );
    $workflow_model->log_dir($self->output_directory);

    for my $chr  (@{$self->chromosome_list}) {
        # Get the hashref that contains all versions to be run for a detector
        $workflow_model = $self->_add_chr_job($workflow_model,$chr);
    }

    return $workflow_model;

}

sub _add_chr_job {
    my $self = shift;
    my ($workflow,$chr) = @_;
    my $subclass = "::".$CHR_MEM_USAGE{$chr};
    my $class = 'Genome::Model::Tools::DetectVariants::Somatic::Pindel'; 
    unless($subclass =~ m/Regular/){
        $class .= $subclass;
    }
    my $chr_job = $workflow->add_operation(
            name => "Pindel Chromosome $chr",
            operation_type => Workflow::OperationType::Command->get($class),
    );
    my @properties =  ( 'reference_sequence_input', 'aligned_reads_input', 'control_aligned_reads_input', 'output_directory','version', );
    for my $property ( @properties) {
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $property,
            right_operation => $chr_job,
            right_property => $property,
        );
    }
    my $chr_property = "chr_$chr";

    $workflow->add_link(
        left_operation => $chr_job,
        left_property => 'output_directory',
        right_operation => $workflow->get_output_connector,
        right_property => 'Chr_'.$chr."_output",
    );

    my $input_connector = $workflow->get_input_connector;
    my $input_connector_properties = $input_connector->operation_type->output_properties;
    push @{$input_connector_properties}, $chr_property;
    $input_connector->operation_type->output_properties($input_connector_properties);

    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => $chr_property,
        right_operation => $chr_job,
        right_property => 'chromosome',
    );

    return $workflow
}

1;
