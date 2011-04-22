package Genome::Model::Tools::DetectVariants2::Breakdancer;

use warnings;
use strict;

use Genome;

my @FULL_CHR_LIST = (1..22, 'X', 'Y');

class Genome::Model::Tools::DetectVariants2::Breakdancer{
    is => 'Genome::Model::Tools::DetectVariants2::Detector',
    has => [
        _config_base_name => {
            is => 'Text',
            default_value => 'breakdancer_config',
            is_constant => 1,
        },
        config_file => {
            #calculate_from => ['_config_base_name', 'output_directory'],
            #calculate => q{ join("/", $output_directory, $_config_base_name); },
            is_output   => 1,
            is_input    => 1,
            is_optional => 1,
            doc => 'breakdancer config file path if provided not made by this tool',
        },
        _config_staging_output => {
            calculate_from => ['_temp_staging_directory', '_config_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_config_base_name); },
            is_optional => 1,
        },
        chromosome => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            valid_values => [@FULL_CHR_LIST, 'all'],
            default_value => 'all',
        },
        version => {
            is => 'Version',
            is_optional => 1,
            is_input => 1,
            default_value =>  Genome::Model::Tools::Breakdancer->default_breakdancer_version,
            valid_values  => [Genome::Model::Tools::Breakdancer->available_breakdancer_versions],
            doc => "Version of breakdancer to use",
        },
        workflow_log_dir => {
            is => 'Text',
            calculate_from => 'output_directory',
            calculate => q{ return $output_directory . '/workflow_log/'; },
            is_optional => 1,
            doc => 'workflow log directory of per chromosome breakdancer run',
        },
        detect_svs => { value => 1, is_constant => 1, },
        sv_params => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            doc => "Parameters to pass to bam2cfg and breakdancer. The two should be separated by a ':'. i.e. 'bam2cfg params:breakdancer params'",
        },
        _bam2cfg_params=> {
            calculate_from => ['sv_params'],
            calculate => q{
                return (split(':', $sv_params))[0];
            },
            is_optional => 1,
            doc => 'This is the property used internally by the tool for bam2cfg parameters. It splits sv_params.',
        },
        _breakdancer_params => {
            calculate_from => ['sv_params'],
            calculate => q{
                return (split(':', $sv_params))[1];
            },
            is_optional => 1,
            doc => 'This is the property used internally by the tool for breakdancer parameters. It splits sv_params.',
        },
    ],
    has_param => [ 
        lsf_resource => {
            default_value => "-M 10000000 -R 'select[localdata && mem>10000] rusage[mem=10000]'",
        },
    ],
    # These are params from the superclass' standard API that we do not require for this class (dont show in the help)
    has_constant_optional => [
        snv_params=>{},
        indel_params=>{},
        capture_set_input =>{},
        detect_snvs=>{},
        detect_indels=>{},
    ],
};


sub help_brief {
    "discovers structural variation using breakdancer",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 breakdancer -aligned-reads-input tumor.bam -control-aligned-reads-input normal.bam --output-dir breakdancer_dir
gmt detect-variants2 breakdancer -aligned-reads-input tumor.bam -control-aligned-reads-input normal.bam --output-dir breakdancer_dir --version 0.0.1r59
EOS
}

sub help_detail {                           
    return <<EOS 
This tool discovers structural variation.  It generates an appropriate configuration based on
the input BAM files and then uses that configuration to run breakdancer.
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
    
    $self->set_params;
    $self->run_config;
    $self->run_breakdancer;

    return 1;
}


sub set_params {
    my $self = shift;

    unless ($self->sv_params) {
        $self->warning_message ("No sv_params option provided. Now try params");
        unless ($self->params) {
            $self->error_message("Neither sv_params nor params is set");
            die;
        }
        $self->sv_params($self->params);
    }
    return 1;
}


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

        my $bam2cfg = Genome::Model::Tools::Breakdancer::BamToConfig->create(
            normal_bam  => $self->control_aligned_reads_input,
            tumor_bam   => $self->aligned_reads_input,
            output_file => $self->_config_staging_output,
            params      => $self->_bam2cfg_params,
            use_version => $self->version,
        );

        unless ($bam2cfg->execute) {
            $self->error_message("Failed to run bam2cfg");
            die;
        }

        $self->config_file($self->_config_staging_output);
        $self->status_message('Breakdancer config is created ok');
    }
    return 1;
}


sub run_breakdancer {
    my $self = shift;
    my $bd_params = $self->_breakdancer_params;

    #Allow 0 size of config, breakdancer output
    if (-z $self->config_file) {
        $self->warning_message("0 size of breakdancer config file. Probably it is for testing of small bam files");
        my $output_file = $self->_sv_staging_output;
        `touch $output_file`;
        return 1;
    }

    if ($bd_params =~ /\-o/) {
        my $chr = $self->chromosome;
        if ($chr eq 'all') {
            require Workflow::Simple;
        
            my $op = Workflow::Operation->create(
                name => 'Breakdancer by chromosome',
                operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::DetectVariants2::Breakdancer'),
            );

            $op->parallel_by('chromosome');
            if ($self->workflow_log_dir) {
                unless (-d $self->workflow_log_dir) {
                    unless (Genome::Sys->create_directory($self->workflow_log_dir)) {
                        $self->error_message('Failed to create workflow_log_dir: '. $self->workflow_log_dir);
                        die;
                    }
                }
                $op->log_dir($self->workflow_log_dir);
            }

            my $cfg_file = $self->config_file;

            unless (Genome::Sys->check_for_path_existence($cfg_file)) {
                $self->error_message('prerun breakdancer config file '.$cfg_file.' does not exist');
                die $self->error_message;
            }

            my @chr_list = $self->_get_chr_list;
            if (scalar @chr_list == 0) {
                #FIXME Sometimes samtools idxstats does not get correct
                #stats because of bam's bai file is not created by
                #later samtools version (0.1.9 ?)
                $self->warning_message("chr list from samtools idxstats is empty, using full chr list now"); 
                @chr_list = @FULL_CHR_LIST;
            }

            $self->status_message('chromosome list is '.join ',', @chr_list);

            my $output = Workflow::Simple::run_workflow_lsf(
                $op,
                aligned_reads_input         => $self->aligned_reads_input, 
                control_aligned_reads_input => $self->control_aligned_reads_input,
                reference_build_id          => $self->reference_build_id,
                output_directory            => $self->_temp_staging_directory,
                config_file => $cfg_file,
                sv_params   => $self->sv_params,
                version     => $self->version,
                chromosome  => \@chr_list,
            );
            unless (defined $output) {
                my @error;
                for (@Workflow::Simple::ERROR) {
                    push @error, $_->error;
                }
                $self->error_message(join("\n", @error));
                die $self->error_message;
            }

            my $merge_obj = Genome::Model::Tools::Breakdancer::MergeFiles->create(
                input_files => join(',', map { $self->_temp_staging_directory . '/' . $self->_sv_base_name . '.' . $_ } @chr_list),
                output_file => $self->_sv_staging_output,
            );
            my $merge_rv = $merge_obj->execute;
            Carp::confess 'Could not execute breakdancer file merging!' unless defined $merge_rv and $merge_rv == 1;

            return 1;
        }
        else {
            $self->_sv_base_name($self->_sv_base_name . '.' . $chr); 
            $bd_params =~ s/\-o/\-o $chr/;
        }
    }
    elsif ($bd_params =~ /\-d/) {
        my $sv_staging_out = $self->_sv_staging_output;
        $bd_params =~ s/\-d/\-d $sv_staging_out/;
    }

    my $breakdancer_path = Genome::Model::Tools::Breakdancer->breakdancer_max_command_for_version($self->version);
    my $cfg_file         = $self->config_file;

    my $cmd = "$breakdancer_path " . $cfg_file . " " . $bd_params . " > "  . $self->_sv_staging_output;

    $self->status_message("EXECUTING BREAKDANCER STEP: $cmd");
    my $return = Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files  => [$cfg_file],
        output_files => [$self->_sv_staging_output],
        allow_zero_size_output_files => 1,
    );

    unless ($return) {
        $self->error_message("Running breakdancer failed using command: $cmd");
        die;
    }

    unless (-s $self->_sv_staging_output) {
        $self->error_message("$cmd output " . $self->_sv_staging_output . " does not exist or has zero size");
        die;
    }

    $self->status_message('breakdancer run finished ok');
    return 1;
}

sub _get_chr_list {
    my $self = shift;

    my $tmp_idx_dir = File::Temp::tempdir(
        "Normal_bam_idxstats_XXXXX",
        CLEANUP => 1,
        DIR     => '/tmp',  #File::Temp can not remove inside dir for _temp_staging_dir
        #DIR     => $self->_temp_staging_directory,
    );

    my $tmp_idx_file = $tmp_idx_dir . '/normal_bam.idxstats';

    my $idxstats = Genome::Model::Tools::Sam::Idxstats->create(
        bam_file    => $self->control_aligned_reads_input,
        output_file => $tmp_idx_file,
    );
    unless ($idxstats->execute) {
        $self->error_message("Failed to run samtools idxstats output $tmp_idx_file");
        die;
    }

    my $unmap_chr_list = $idxstats->unmap_ref_list($tmp_idx_file);
    my @chr_list; 

    for my $chr (@FULL_CHR_LIST) {
        push @chr_list, $chr unless grep{$chr eq $_}@$unmap_chr_list;
    }

    return @chr_list;
}


sub has_version {
    my $self    = shift;
    my $version = shift;

    unless (defined $version) {
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::Breakdancer->available_breakdancer_versions;
    for my $v (@versions) {
        if ($v eq $version) {
            return 1;
        }
    }
    return 0;  
}

1;
