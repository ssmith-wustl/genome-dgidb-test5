package Genome::Model::Tools::DetectVariants::Somatic::Breakdancer;

use warnings;
use strict;

use Genome;

my $DEFAULT_VERSION = '2010_06_24';

class Genome::Model::Tools::DetectVariants::Somatic::Breakdancer{
    is => 'Genome::Model::Tools::DetectVariants::Somatic',
    has => [
        _config_base_name => {
            is => 'Text',
            default_value => 'breakdancer_config',
            is_input => 1,
        },
        config_output => {
            calculate_from => ['_config_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_config_base_name); },
            is_output => 1,
        },
        _config_staging_output => {
            calculate_from => ['_temp_staging_directory', '_config_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_config_base_name); },
        },
        version => {
            is => 'Version',
            is_optional => 1,
            is_input => 1,
            default_value => $DEFAULT_VERSION,
            doc => "Version of breakdancer to use"
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
            doc => 'This is the property used internally by the tool for bam2cfg parameters. It splits sv_params.',
        },
        _breakdancer_params => {
            calculate_from => ['sv_params'],
            calculate => q{
                return (split(':', $sv_params))[1];
            },
            doc => 'This is the property used internally by the tool for breakdancer parameters. It splits sv_params.',
        },
        skip => {
            is => 'Boolean',
            default => '0',
            is_input => 1,
            is_optional => 1,
            doc => "If set to true... this will do nothing! Fairly useless, except this is necessary for workflow.",
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut this step if the output is already present. Useful for pipelines.',
        },
        ],
    has_param => [ 
        lsf_resource => {
            default_value => "-M 8000000 -R 'select[type==LINUX64 && mem>8000] rusage[mem=8000]'",
        },
        lsf_queue => {
            default_value => 'long'
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

my %BREAKDANCER_BASE_DIRS = (
    '0.0.1r59' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-0.0.1r59',
    '2010_02_17' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-2010_02_17/bin',
    '2010_03_02' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-2010_03_02/bin',
    '2010_06_24' => '/gsc/pkg/bio/breakdancermax/breakdancer-20100624',
);

my %BREAKDANCER_CONFIG_COMMAND = (
    '0.0.1r59' => 'bam2cfg.pl',
    '2010_02_17' => 'bam2cfg.pl',
    '2010_03_02' => 'bam2cfg.pl',
    '2010_06_24' => 'perl/bam2cfg.pl',
);

my %BREAKDANCER_MAX_COMMAND = (
    '0.0.1r59' => 'BreakDancerMax.pl',
    '2010_02_17' => 'BreakDancerMax.pl',
    '2010_03_02' => 'BreakDancerMax.pl',
    '2010_06_24' => 'cpp/breakdancer_max',
);

sub help_brief {
    "discovers structural variation using breakdancer",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt somatic breakdancer -t tumor.bam -n normal.bam --output-dir breakdancer_dir
gmt somatic breakdancer -t tumor.bam -n normal.bam --output-dir breakdancer_dir --version 0.0.1r59 --skip-if-output-present 
EOS
}

sub help_detail {                           
    return <<EOS 
This tool discovers structural variation.  It generates an appropriate configuration based on
the input BAM files and then uses that configuration to run breakdancer.
EOS
}

sub _should_skip_execution {
    my $self = shift;
    
    if ($self->skip) {
        $self->status_message("Skipping execution: Skip flag set");
        return 1;
    }
    if (($self->skip_if_output_present)&&(-s $self->sv_output)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }
    
    return $self->SUPER::_should_skip_execution;
}

sub _detect_variants {
    my $self = shift;
    
    $self->run_config;

    $self->run_breakdancer;

    return 1;
}

sub run_config {
    my $self = shift;

    my $config_path = $self->breakdancer_config_command;
    my $cmd = "$config_path " . $self->aligned_reads_input . " " . $self->control_aligned_reads_input . " " . $self->_bam2cfg_params . " > "  . $self->_config_staging_output;
    $self->status_message("EXECUTING CONFIG STEP: $cmd");
    my $return = Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->aligned_reads_input, $self->control_aligned_reads_input],
        output_files => [$self->_config_staging_output],
    );

    unless ($return) {
        $self->error_message("Running breakdancer config failed using command: $cmd");
        die;
    }

    unless (-s $self->_config_staging_output) {
        $self->error_message("$cmd output " . $self->_config_staging_output . " does not exist or has zero size");
        die;
    }

    
    return 1;
}

sub run_breakdancer {
    my $self = shift;

    my $breakdancer_path = $self->breakdancer_max_command;
    my $cmd = "$breakdancer_path " . $self->_config_staging_output . " " . $self->_breakdancer_params . " > "  . $self->_sv_staging_output;
    $self->status_message("EXECUTING BREAKDANCER STEP: $cmd");
    my $return = Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->_config_staging_output],
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
 

    return 1;
}

sub breakdancer_path {
    my $self = $_[0];
    return $self->path_for_breakdancer_version($self->version);
}

sub breakdancer_max_command { 
    my $self = $_[0];
    return $self->breakdancer_max_command_for_version($self->version);
}

sub breakdancer_config_command { 
    my $self = $_[0];
    return $self->breakdancer_config_command_for_version($self->version);
}

sub available_breakdancer_versions {
    my $self = shift;
    return keys %BREAKDANCER_BASE_DIRS;
}

sub path_for_breakdancer_version {
    my $class = shift;
    my $version = shift;

    if (defined $BREAKDANCER_BASE_DIRS{$version}) {
        return $BREAKDANCER_BASE_DIRS{$version};
    }
    die('No path for breakdancer version '. $version);
}

sub breakdancer_max_command_for_version {
    my $class = shift;
    my $version = shift;

    if (defined $BREAKDANCER_MAX_COMMAND{$version}) {
        return $class->path_for_breakdancer_version($version) . "/" .  $BREAKDANCER_MAX_COMMAND{$version};
    }
    die('No breakdancer max command for breakdancer version '. $version);
}

sub breakdancer_config_command_for_version {
    my $class = shift;
    my $version = shift;

    if (defined $BREAKDANCER_CONFIG_COMMAND{$version}) {
        return $class->path_for_breakdancer_version($version) . "/" .  $BREAKDANCER_CONFIG_COMMAND{$version};
    }
    die('No breakdancer config command for breakdancer version '. $version);
}

sub default_breakdancer_version {
    die "default breakdancer version: $DEFAULT_VERSION is not valid" unless $BREAKDANCER_BASE_DIRS{$DEFAULT_VERSION};
    return $DEFAULT_VERSION;
}
 
1;
