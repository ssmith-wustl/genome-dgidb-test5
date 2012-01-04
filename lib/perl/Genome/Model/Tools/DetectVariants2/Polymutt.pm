package Genome::Model::Tools::DetectVariants2::Polymutt;

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::DetectVariants2::Polymutt {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    #has => [
    #    params => {},
    #],
    has_param => [
        lsf_resource => {
            default => "-q workflow ", #hope that works
        }
    ],
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 polymutt --alignment-results input.bam --reference_sequence_input reference.fa --output-directory ~/example/
EOS
}

sub help_detail {
    return <<EOS 
This tool runs Polymutt for detection of SNPs and/or indels.
EOS
}

sub _supports_cross_sample_detection {
    my ($class, $version, $vtype, $params) = @_;
    return 1;
};

sub output_dir {
    my $self = shift;
    #FIXME
    die "where am i getting output directory from";
    #FIXME
}

sub ped_file {
    my $self = shift;
    #FIXME
    die "implement passthrough pedfile";
    #FIXME
}

sub _detect_variants {
    my $self = shift;

    my $version = $self->version;
    unless ($version) {
        die $self->error_message("A version of Polymutt must be specified");
    }
    my @alignments = $self->alignment_results;
    my @glfs = $self->generate_glfs(@alignments);
    my $dat_file = $self->generate_dat();
    #FIXME ensure glfindex matches index number in ped.  the current code expects both alphabetical by sample name, but does not check or enforce it.  
    my $glf_index = $self->generate_glfindex(@glfs);
    #FIXME
    $self->run_polymutt($dat_file, $glf_index);
   return 1;
}


sub run_polymutt {
    my($self, $dat_file, $glf_index) = @_;
    my $ped_file = $self->ped_file;
    my %inputs;
    $inputs{dat_file}=$dat_file;
    $inputs{ped_file}=$ped_file;
    $inputs{denovo}=1;
    $inputs{glf_index}=$glf_index;
    #FIXME: if we intend to make one ped per project and just run subsets with it, this could would need to be more complex
    #i.e. if 10 families reside in one pedfile, and we supply a glfindex for just one of those families, this code is bad
    chomp(my $family_id = `head -n 1 $ped_file | cut -f 1`); 
    #FIXME:
    $inputs{output_denovo} = $self->output_dir . "/$family_id.denovo.vcf";
    $inputs{output_standard} = $self->output_dir . "/$family_id.standard.vcf";
    my $workflow = Workflow::Model->create(
        name=> "Run polymutt standard and denov",
        input_properties => [
        'dat_file',
        'glf_index',
        'ped_file',
        'output_denovo',
        'output_standard',
        'denovo',
        ],
        output_properties => [
        'output',
        ],
    );
    my $denovo_op = $workflow->add_operation(
        name=>"denovo polymutt",
        operation_type=>Workflow::OperationType::Command->get("Genome::Model::Tools::Relationship::RunPolymutt"),
    );
    my $standard_op = $workflow->add_operation(
        name=>"standard polymutt",
        operation_type=>Workflow::OperationType::Command->get("Genome::Model::Tools::Relationship::RunPolymutt"),
    );
    for my $op ($denovo_op, $standard_op) {
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"dat_file",
            right_operation=>$op,
            right_property=>"dat_file",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"glf_index",
            right_operation=>$op,
            right_property=>"glf_index",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"ped_file",
            right_operation=>$op,
            right_property=>"ped_file",
        );
        $workflow->add_link(
            left_operation=>$op,
            left_property=>"output_vcf",
            right_operation=>$workflow->get_output_connector,
            right_property=>"output",
        );
    }
    $workflow->add_link(
        left_operation=>$workflow->get_input_connector,
        left_property=>"output_denovo",
        right_operation=>$denovo_op,
        right_property=>"output_vcf",
    );
    $workflow->add_link(
        left_operation=>$workflow->get_input_connector,
        left_property=>"output_standard",
        right_operation=>$standard_op,
        right_property=>"output_vcf",
    );
    $workflow->add_link(
        left_operation=>$workflow->get_input_connector,
        left_property=>"denovo",
        right_operation=>$denovo_op,
        right_property=>"denovo",
    );
    my @errors = $workflow->validate;
    $workflow->log_dir($self->output_dir);
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->status_message("Now launching 2 polymutt jobs");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);
    unless($result) {
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        $self->error_message("parallel polymutt did not return correctly.");
        die;
    }

}




sub generate_dat {
    my $self = shift;
    my $out_file_name = $self->output_dir . "/" . "polymutt.dat";
    my $dat_fh = IO::File->new($out_file_name, ">");
    $dat_fh->print("T\tGLF_Index\n"); #this is required because the pedfile may have arbitrarily many attributes after the first 5 columns, which you can label and polymutt will ignore. but we never do that, so it always looks like this
    $dat_fh->close;
    return $out_file_name;
}

sub generate_glfindex {
    my $self=shift;
    my @glfs = @_;
    my $glf_name = $self->output_dir ."/" . "polymutt.glfindex";
    my $glf_fh = IO::File->new($glf_name, ">");
    my $count =1;
    for my $glf (sort @glfs) {  #again we just assume the incoming ped file is alpha sorted, so we alpha sort
        $glf_fh->print("$count\t$glf\n");
        $count++;
    }
    $glf_fh->close;
    return $glf_name;
}



sub generate_glfs {
    my $self = shift;
    my @alignments = @_;
    my %inputs;
    my (@outputs, @inputs);
    $inputs{ref_fasta} = $alignments[0]->reference_sequence_build->full_consensus_path("fa");

#    my $bam_path = $a->merged_alignment_bam_path;
    for (my $i =0; $i < scalar(@alignments); $i++) {
        my $output_name = $self->output_dir . "/" . $alignments[$i]->instrument_data->sample_name . ".glf";
        push @outputs, $output_name;
        $inputs{"bam_$i"}=$alignments[$i]->merged_alignment_bam_path;
        $inputs{"output_glf_$i"}=$output_name;
        push @inputs, ("bam_$i", "output_glf_$i");
    }
    my $workflow = Workflow::Model->create(
        name=> "polymutt parallel glf file creation",
        input_properties => [
        'ref_fasta',
        @inputs,
        ],
        output_properties => [
        'output',
        ],
    );
    for(my $i=0; $i< scalar(@alignments); $i++) {
        my $hybridview_op = $workflow->add_operation(
            name=>"glf creation $i",
            operation_type=>Workflow::OperationType::Command->get("Genome::Model::Tools::Samtools::HybridView"),
        );

        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"ref_fasta",
            right_operation=>$hybridview_op,
            right_property=>"ref_fasta",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"bam_$i",
            right_operation=>$hybridview_op,
            right_property=>"bam",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"output_glf_$i",
            right_operation=>$hybridview_op,
            right_property=>"output_glf",
        );
        $workflow->add_link(
            left_operation=>$hybridview_op,
            left_property=>"output_glf",
            right_operation=>$workflow->get_output_connector,
            right_property=>"output",
        );
    }
    my @errors = $workflow->validate;
    $workflow->log_dir($self->output_dir);
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->status_message("Now launching glf generation jobs");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);
    unless($result) {
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("parallel glf generation workflow did not return correctly.");
    }
    return @outputs;
}


sub generate_metrics {
    my $self = shift;

    my $metrics = {};
    
    if($self->detect_snvs) {
        my $snp_count      = 0;
        
        my $snv_output = $self->_snv_staging_output;
        my $snv_fh = Genome::Sys->open_file_for_reading($snv_output);
        while (my $row = $snv_fh->getline) {
            $snp_count++;
        }
        $metrics->{'total_snp_count'} = $snp_count;
    }

    if($self->detect_indels) {
        my $indel_count    = 0;
        
        my $indel_output = $self->_indel_staging_output;
        my $indel_fh = Genome::Sys->open_file_for_reading($indel_output);
        while (my $row = $indel_fh->getline) {
            $indel_count++;
        }
        $metrics->{'total indel count'} = $indel_count;
    }

    return $metrics;
}

sub has_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::Polymutt->available_varscan_versions;
    for my $v (@versions){
        if($v eq $version){
            return 1;
        }
    }
    return 0;  
}

sub parse_line_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    unless ($line) {
        die $class->error_message("No line provided to parse_line_for_bed_intersection");
    }

    my ($chromosome, $position, $_reference, $consensus) = split "\t",  $line;

    if ($consensus =~ /\-|\+/) {
        return $class->_parse_indel_for_bed_intersection($line);
    } else {
        return $class->_parse_snv_for_bed_intersection($line);
    }
}

sub _parse_indel_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $_reference, $consensus, @extra) = split "\t",  $line;
    
    my @variants;
    my @indels = Genome::Model::Tools::Bed::Convert::Indel::PolymuttToBed->convert_indel($line);

    for my $indel (@indels) {
        my ($reference, $variant, $start, $stop) = @$indel;
        if (defined $chromosome && defined $position && defined $reference && defined $variant) {
            push @variants, [$chromosome, $stop, $reference, $variant];
        }
    }

    unless(@variants){
        die $class->error_message("Could not get chromosome, position, reference, or variant for line: $line");
    }

    return @variants;
}

sub _parse_snv_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $reference, $consensus, @extra) = split("\t", $line);

    return [$chromosome, $position, $reference, $consensus];
}

1;
