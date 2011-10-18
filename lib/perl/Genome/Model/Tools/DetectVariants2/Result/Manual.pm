package Genome::Model::Tools::DetectVariants2::Result::Manual;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result::Manual {
    is => 'Genome::SoftwareResult::Stageable',
    has_input => [
        file_content_hash => {
            is => 'Text',
            doc => 'MD5 hash of the file that is contained in this result',
        },
        sample_id => {
            is => 'Number',
            doc => 'ID of the "tumor" sample for these variants',
        },
        reference_build_id => {
            is => 'Number',
            doc => 'ID of the reference sequence build used for alignment/variant detection',
        },
    ],
    has_param => [
        variant_type => {
            is => 'Text',
            doc => 'the type of variants',
            valid_values => ['snv','indel','sv','cnv'],
        },
        format => {
            is => 'Text',
            doc => 'The format of the variant file',
        },
    ],
    has_optional_input => [
        control_sample_id => {
            is => 'Number',
            doc => 'ID of the "normal"/"control" sample for these variants (when applicable)',
        },
        source_build_id => {
            is => 'Number',
            doc => 'ID of the build from which this variant list is defined',
        },
    ],
    has_optional_metric => [
        original_file_path => {
            is => 'Text',
            doc => 'Path to the original file used to create this result',
        },
        description => {
            is => 'Text',
            doc => 'How this list was created, the source of the list, etc.',
        },
        username => {
            is => 'Text',
            doc => 'the user that created this result',
        },
    ],
    has => [
        previous_result => {
            is => 'Genome::SoftwareResult',
            id_by => 'previous_result_id',
            doc => 'The result upon which these manually chosen variants were based',
        },
        source_build => {
            is => 'Genome::Model::Build',
            id_by => 'source_build_id',
            doc => 'The build which was used to discover the variants upon which this result is based',
        },
        reference_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            id_by => 'reference_build_id',
            doc => 'Reference sequence build used for alignment/variant detection',
        },
        sample => {
            is => 'Genome::Sample',
            id_by => 'sample_id',
        },
        control_sample => {
            is => 'Genome::Sample',
            id_by => 'control_sample_id',
        },
        aligned_reads_sample => { #name to match GMT DV2 Base
            is => 'Text',
            via => 'sample',
            to => 'name',
        },
    ],
    has_optional_input => [
        previous_result_id => {
            is => 'Text',
            doc => 'ID of the result upon which these manually chosen variants were based',
        },
    ],
};

sub _gather_params_for_get_or_create {
    my $class = shift;

    my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, @_);

    if($bx->specifies_value_for('original_file_path')) {
        my $val = $bx->value_for('original_file_path');
        if(-e $val) {
            my $checksum = Genome::Sys->md5sum($val);
            if($bx->specifies_value_for('file_content_hash')) {
                unless($bx->value_for('file_content_hash') eq $val) {
                    die('file_content_hash does not match md5sum output for the original file.');
                }
            } else {
                $bx = $bx->add_filter('file_content_hash', $val);
            }
        }
    }

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

    my $subclass_name = (exists $is_param{filter_name} ? 'Genome::Model::Tools::DetectVariants2::Result::Filter' : 'Genome::Model::Tools::DetectVariants2::Result');

    my %software_result_params = (
        params_id => $params_bx->id,
        inputs_id => $inputs_bx->id,
        subclass_name => $class,
    );

    return {
        software_result_params => \%software_result_params,
        subclass => $class,
        inputs => \%is_input,
        params => \%is_param,
    };
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $user = Genome::Sys->username;
    my $sudo_user = Genome::Sys->sudo_username;
    $user .= " ($sudo_user)" if $sudo_user;
    $self->username($user);

    $self->_prepare_staging_directory;

    my $symlink_dest = join('/', $self->temp_staging_directory, $self->variant_type . 's.hq');
    Genome::Sys->create_symlink($self->original_file_path, $symlink_dest);

    $self->generate_standard_files($symlink_dest);

    $self->_prepare_output_directory;
    $self->_promote_data;
    $self->_reallocate_disk_allocation;

    return $self;
}

sub generate_standard_files {
    my $self = shift;
    my $source = shift;

    my %converters = (
        bed => 'Genome::Model::Tools::Bed::Convert::' . ucfirst($self->variant_type) . '::' . ucfirst($self->format) . 'ToBed',
        vcf => 'Genome::Model::Tools::Vcf::Convert::' . ucfirst($self->variant_type) . '::' . ucfirst($self->format),
    );

    if(lc($self->format) eq 'bed') {
        Genome::Sys->create_symlink($source, $source . '.bed');
    } elsif($converters{bed}->isa('Command')) {
        Genome::Model::Tools::DetectVariants2::Base->class; #autoload
        die($self->error_message('Conversion to bed failed')) unless Genome::Model::Tools::DetectVariants2::Base::_run_bed_converter($self, $converters{bed}, $source);
    }

    if(lc($self->format) eq 'vcf') {
        Genome::Sys->shellcmd(
            cmd => 'bgzip -c ' . $source . ' > ' . $source . '.vcf.gz',
            input_files => [$source],
            output_files => [$source . '.vcf.gz']
        );
    } elsif($converters{vcf}->isa('Command')) {
        Genome::Model::Tools::DetectVariants2::Base->class; #autoload
        die($self->error_message('Conversion to bed failed')) unless Genome::Model::Tools::DetectVariants2::Base::_run_vcf_converter($self, $converters{vcf}, $source, $self->variant_type .'s');
    }

    return 1;
}

sub resolve_allocation_subdirectory {
    Genome::Model::Tools::DetectVariants2::Result::Base->class; #autoload
    return Genome::Model::Tools::DetectVariants2::Result::Base::_resolve_subdirectory(@_);
}

sub resolve_allocation_disk_group_name { return 'info_genome_models'; }

sub _needs_symlinks_followed_when_syncing { return 1; }

sub _staging_disk_usage { return 2 * (-s $_[0]->original_file_path); }

