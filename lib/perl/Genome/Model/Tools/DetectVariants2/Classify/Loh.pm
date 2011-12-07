package Genome::Model::Tools::DetectVariants2::Classify::Loh;

use strict;
use warnings;

use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::DetectVariants2::Classify::Loh {
    is => 'Genome::Model::Tools::DetectVariants2::Result::Classify',
    has_input =>[
        prior_result_id => {
            is => 'Text',
            doc => 'ID of the snv results considered "somatic"',
        },
        control_result_id => {
            is => 'Text',
            doc => 'ID of the snv results considered "germline"',
        },
    ],
    has_param => [
        classifier_version => {
            is => 'Text',
            doc => 'Version of the classifier to use',
        }
    ],
    has => [
        prior_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'prior_result_id',
        },
        control_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'control_result_id',
        },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    unless($self->_validate_inputs) {
        my $err = $self->error_message;
        die $self->error_message('Failed to validate inputs: ' . $err);
    }

    unless($self->_prepare_staging_directory) {
        die $self->error_message('Failed to prepare staging directory.');
    }

    unless($self->_generate_result) {
        die $self->error_message('Failed to run LOH.');
    }

    unless($self->_prepare_output_directory) {
        die $self->error_message('Failed to prepare output directory.');
    }

    unless($self->_promote_data) {
        die $self->error_message('Failed to promote data.');
    }

    return $self;
}

sub _validate_inputs {
    my $self = shift;

    unless($self->prior_result) {
        $self->error_message('No Somatic SNV result found.');
        return;
    }

    unless(-e (join('/', $self->prior_result->output_dir, 'snvs.hq.bed'))) {
        $self->error_message('Could not find snvs file for somatic result.');
        return;
    }

    unless($self->control_result) {
        $self->error_message('No Control SNV result found.');
        return;
    }

    unless(-e (join('/', $self->control_result->output_dir, 'snvs.hq.bed'))) {
        $self->error_message('Could not find snvs file for control result.');
        return;
    }

    unless($self->classifier_version eq '1') {
        $self->error_message('Unsupported classifier version passed.  Supported versions: 1');
        return;
    }

    return 1;
}

sub _generate_result {
    my $self = shift;

    my $version = 2;
    my $control_variant_file = join('/', $self->control_result->output_dir, 'snvs.hq.bed');
    my $detected_snvs = join('/', $self->prior_result->output_dir, 'snvs.hq.bed');

    my $output_dir = $self->temp_staging_directory;
    my $somatic_output = $output_dir."/snvs.somatic.v".$version.".bed";
    my $loh_output = $output_dir."/snvs.loh.v".$version.".bed";

    return $self->run_loh($control_variant_file, $detected_snvs, $somatic_output, $loh_output);
}

sub run_loh {
    my $self = shift;
    my ($control_variant_file,$detected_snvs,$somatic_output,$loh_output) = @_;

    my $somatic_fh = Genome::Sys->open_file_for_writing($somatic_output);
    my $loh_fh = Genome::Sys->open_file_for_writing($loh_output);

    my $normal_snp_fh = Genome::Sys->open_file_for_reading($control_variant_file);
    my $input_fh = Genome::Sys->open_file_for_reading($detected_snvs);

    #MAKE A HASH OF NORMAL SNPS!!!!!!!!!!!!!
    #Assuming that we will generally be doing this on small enough files (I hope). I suck. -- preserved in time from dlarson
    my %normal_variants;
    while(my $line = $normal_snp_fh->getline) {
        chomp $line;
        my ($chr, $start, $pos2, $ref,$var) = split /\t/, $line;
        my $var_iub;
        #Detect if ref and var columns are combined
        if($ref =~ m/\//){
            ($ref,$var_iub) = split("/", $ref);
        }
        else {
            $var_iub = $var;
        }
        #first find all heterozygous sites in normal
        next if($var_iub =~ /[ACTG]/);
        my @alleles = Genome::Info::IUB->iub_to_alleles($var_iub);
        $normal_variants{$chr}{$start} = join '',@alleles;
    }
    $normal_snp_fh->close;

    # Go through input variants. If a variant was called in both the input set and the control set (normal samtools calls):
    # If that variant was heterozygous in the control call and became homozygous in the input set, it is considered a loss of heterozygocity event, and goes in the LQ file
    # Otherwise it is not filtered out, and remains in the HQ output
    while(my $line = $input_fh->getline) {
        chomp $line;

        my ($chr, $start, $stop, $ref_and_iub) = split /\t/, $line;
        my ($ref, $var_iub) = split("/", $ref_and_iub);

        #now compare to homozygous sites in the tumor
        if ($var_iub =~ /[ACTG]/ && exists($normal_variants{$chr}{$start})) {
            if(index($normal_variants{$chr}{$start},$var_iub) > -1) {
                #then they share this allele and it is LOH
                $loh_fh->print("$line\n");
            }
            else {
                $somatic_fh->print("$line\n");
            }
        }
        else {
            $somatic_fh->print("$line\n");
        }
    }
    $input_fh->close;
    return 1;
}

sub _needs_symlinks_followed_when_syncing { 0 };
sub _working_dir_prefix { 'dv2-loh-result' };
sub resolve_allocation_disk_group_name { 'info_genome_models' };

sub resolve_allocation_subdirectory {
    my $self = shift;
    my $staged_basename = File::Basename::basename($self->temp_staging_directory);
    return join('/', 'build_merged_alignments', $self->id, 'dv2-classify-loh-' . $staged_basename);
};

sub _gather_params_for_get_or_create {
    my $class = shift;

    my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, @_);

    my %params = $bx->params_list;
    my %is_input;
    my %is_param;
    my $class_object = $class->__meta__;
    for my $key ($class->property_names) {
        my $meta = $class_object->property_meta_for_name($key);
        if ($meta->{is_input} && exists $params{$key}) {
            $is_input{$key} = $params{$key};
        } elsif ($meta->{is_param} && exists $params{$key}) {
            $is_param{$key} = $params{$key};
        }
    }

    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_input);
    my $params_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_param);

    my %software_result_params = (
        params_id=>$params_bx->id,
        inputs_id=>$inputs_bx->id,
        subclass_name=>$class,
    );

    return {
        software_result_params => \%software_result_params,
        subclass => $class,
        inputs=>\%is_input,
        params=>\%is_param,
    };
}

1;
