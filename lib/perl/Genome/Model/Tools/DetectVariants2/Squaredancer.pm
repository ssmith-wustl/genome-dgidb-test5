package Genome::Model::Tools::DetectVariants2::Squaredancer;

use warnings;
use strict;

use Genome;
use File::Basename;


class Genome::Model::Tools::DetectVariants2::Squaredancer{
    is => 'Genome::Model::Tools::DetectVariants2::Detector',
    has => [
        config_file => {
            is_optional => 1,
            doc => 'breakdancer config file path if provided not made by this tool',
        },
        version => {
            is => 'Version',
            doc => "Version of squaredancer to use",
            is_optional => 1,
            default_value => Genome::Model::Tools::Squaredancer->default_squaredancer_version,
            valid_values  => [Genome::Model::Tools::Squaredancer->available_squaredancer_versions],
        },
        squaredancer_path => {
            is  => 'FilePath',
            doc => 'squaredancer executable path to use',
            calculate_from => 'version',
            calculate      => q{return Genome::Model::Tools::Squaredancer->path_for_squaredancer_version($version);},
        },
        breakdancer_version => {
            is => 'Version',
            doc => "Versions of breakdancer to use",
            default_value => Genome::Model::Tools::Breakdancer->default_breakdancer_version,
            valid_values  => [Genome::Model::Tools::Breakdancer->available_breakdancer_versions],
        },
        _config_staging_output   => {
            calculate_from => '_temp_staging_directory',
            calculate => q{ join('/', $_temp_staging_directory, 'breakdancer_config'); },
        },
        _sd_error_staging_output => {
            calculate_from => '_temp_staging_directory',
            calculate => q{ join('/', $_temp_staging_directory, 'Squaredancer.err'); }
        },
    ],
    has_param => [ 
        lsf_resource => {
            default_value => "-M 20000000 -R 'select[mem>20000] rusage[mem=20000]'",
        },
    ],
};


sub help_brief {
    "discovers structural variation using squaredancer",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 squaredancer -aligned-reads-input tumor.bam -control-aligned-reads-input normal.bam --output-dir squaredancer_dir
gmt detect-variants2 squaredancer -aligned-reads-input tumor.bam -control-aligned-reads-input normal.bam --output-dir squaredancer_dir --version 0.0.1r59
EOS
}

sub help_detail {                           
    return <<EOS 
This tool discovers structural variation for soft-clipped genomic or cDNA reads.
EOS
}


sub _create_temp_directories {
    my $self = shift;
    local %ENV = %ENV;
    $ENV{TMPDIR} = $self->output_directory;
    return $self->SUPER::_create_temp_directories(@_);
}


sub _detect_variants {
    my $self = shift;
    
    $self->run_config;  
    $self->run_squaredancer;

    return 1;
}


#tigra-validation need use breakdancer_config to figure out skip_libraries (normal)
sub run_config {
    my $self = shift;
    my $cfg_file = $self->config_file;

    if ($cfg_file) {
        unless (Genome::Sys->check_for_path_existence($cfg_file)) {
            $self->error_message("Given breakdancer config file $cfg_file is not valid");
            die $self->error_message;
        }
        $self->status_message("Using given breakdancer config file: $cfg_file");
    }
    else {
        $self->status_message("Run bam2cfg to make breakdancer_config file");

        my %params = (
            tumor_bam   => $self->aligned_reads_input,
            output_file => $self->_config_staging_output,
            params      => '-g -h', #hardcode for now, not many options necessary for this
            use_version => $self->breakdancer_version,
        );

        $params{normal_bam} = $self->control_aligned_reads_input 
            if $self->control_aligned_reads_input;

        my $bam2cfg = Genome::Model::Tools::Breakdancer::BamToConfig->create(%params);
       
        unless ($bam2cfg->execute) {
            $self->error_message("Failed to run bam2cfg");
            die;
        }

        $self->config_file($self->_config_staging_output);
        $self->status_message('Breakdancer config is created ok');
    }
    return 1;
}


sub run_squaredancer {
    my $self      = shift;
    my $sd_params = $self->params;

    #Allow 0 size of config, breakdancer output
    if (-z $self->config_file) {
        $self->warning_message("0 size of breakdancer config file. Probably it is for testing of small bam files");
        my $output_file = $self->_sv_staging_output;
        `touch $output_file`;
        return 1;
    }

    if ($sd_params =~ /\-l/) { #Some projects like PCGP need screen out normal bam
        my $control_bam = $self->control_aligned_reads_input;
        unless ($control_bam and -s $control_bam) {
            $self->error_message('No control_aligned_reads_input available with -l option: '.$sd_params);
            die;
        }
        my ($skip_control_name) = $control_bam =~ /^(\S+)\.bam$/;
        unless ($skip_control_name) {
            $self->error_message("Failed to get skip_control_name from control bam: $control_bam");
            die;
        }
        $sd_params = '-l '. $skip_control_name;
    }

    my @bam_list;
    for my $bam_type qw(aligned_reads_input control_aligned_reads_input) {
        push @bam_list, $self->$bam_type if $self->$bam_type;
    }
    my $bam_string = join ' ', @bam_list;

    my $sd_path = $self->squaredancer_path;
    my $pl_path = '/usr/bin/perl'; #64 bit perl

    my $cmd = $sd_params ? $sd_path . " $sd_params" : $sd_path;
       $cmd = "$pl_path $cmd $bam_string" . ' 1> ' . $self->_sv_staging_output . ' 2> '. $self->_sd_error_staging_output;

    $self->status_message("EXECUTING SQUAREDANCER STEP: $cmd");
    my $return = Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files  => \@bam_list,
        output_files => [$self->_sv_staging_output],
        allow_zero_size_output_files => 1,
    );

    unless ($return) {
        $self->error_message("Running squaredancer failed using command: $cmd");
        die;
    }

    unless (-s $self->_sv_staging_output) {
        $self->error_message("$cmd output " . $self->_sv_staging_output . " does not exist or has zero size");
        die;
    }

    $self->status_message('Squaredancer run finished ok');
    return 1;
}


sub has_version {
    my $self    = shift;
    my $version = shift;

    unless (defined $version) {
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::Squaredancer->available_squaredancer_versions;
    for my $v (@versions) {
        if ($v eq $version) {
            return 1;
        }
    }
    return 0;  
}


1;
