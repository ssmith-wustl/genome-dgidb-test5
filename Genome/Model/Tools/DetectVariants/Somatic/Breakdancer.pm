package Genome::Model::Tools::DetectVariants::Somatic::Breakdancer;

use warnings;
use strict;

use Genome;

my $DEFAULT_VERSION = '2010_03_02';
my $CONFIG_COMMAND = 'bam2cfg.pl';
my $BREAKDANCER_COMMAND = 'BreakDancerMax.pl';

class Genome::Model::Tools::DetectVariants::Somatic::Breakdancer{
    is => 'Genome::Model::Tools::DetectVariants::Somatic',
    has => [
        sv_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/sv_output.csv' },
            is_output=>1,
        },
        config_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/breakdancer.config' },
        },
        version => {
            is => 'Version',
            is_optional => 1,
            is_input => 1,
            default_value => $DEFAULT_VERSION,
            doc => "Version of breakdancer to use"
        },
        detect_svs => { value => 1, is_constant => 1, },
        #TODO FIXME how to handle command line interface? with the public/private as we used to? This is pretty dumb but works for now since most people arent running breakdancer by itself with this tool.
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
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        ],
    has_param => [ 
        lsf_resource => {
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
        },
        lsf_queue => {
            default_value => 'long'
        }, 
    ],
    # These are params from the superclass' standard API that we do not require for this class (dont show in the help)
    has_constant_optional => [
        snp_params=>{},
        indel_params=>{},
        capture_set_input =>{},
    ],
};


# HACK HACK HACK HACK WARNING THIS IS A HORRIBLE HACK 
# workflow passes in an empty string for use version if the value is undef
# but empty string can't resolve to a version, so stuff the default one in 
# while creating.
################################################
sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    if ($self->version eq "") {
        $self->version($DEFAULT_VERSION);
    }

    return $self; 
}

my %BREAKDANCER_VERSIONS = (
	'0.0.1r59' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-0.0.1r59',
	'2010_02_17' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-2010_02_17/bin',
	'2010_03_02' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-2010_03_02/bin',
);

sub help_brief {
    "discovers structural variation using breakdancer",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt somatic breakdancer -t tumor.bam -n normal.bam --working-dir breakdancer_dir
gmt somatic breakdancer -t tumor.bam -n normal.bam --working-dir breakdancer_dir --use-version 0.0.1r59 --skip-if-output-present 
EOS
}

sub help_detail {                           
    return <<EOS 
This tool discovers structural variation.  It generates an appropriate configuration based on
the input BAM files and then uses that configuration to run breakdancer.
EOS
}

sub execute {
    my $self = shift;

    if ($self->skip) {
        $self->status_message("Skipping execution: Skip flag set");
        return 1;
    }
    if (($self->skip_if_output_present)&&(-s $self->sv_output)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    unless (Genome::Utility::FileSystem->create_directory($self->working_directory) ) {
        $self->error_message("Could not create working_directory: " . $self->working_directory);
        return;
    }

    $self->run_config;

    $self->run_breakdancer;

    return 1;
}

sub run_config {
    my $self = shift;

    my $config_path = $self->breakdancer_path . "/$CONFIG_COMMAND";
    my $cmd = "$config_path " . $self->aligned_reads_input . " " . $self->control_aligned_reads_input . " " . $self->_bam2cfg_params . " > "  . $self->config_output;
    $self->status_message("EXECUTING CONFIG STEP: $cmd");
    my $return = Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->aligned_reads_input, $self->control_aligned_reads_input],
        output_files => [$self->config_output],
    );

    unless ($return) {
        $self->error_message("Running breakdancer config failed using command: $CONFIG_COMMAND");
        die;
    }

    unless (-s $self->config_output) {
        $self->error_message("$CONFIG_COMMAND output " . $self->config_output . " does not exist or has zero size");
        die;
    }

    
    return 1;
}

sub run_breakdancer {
    my $self = shift;

    my $breakdancer_path = $self->breakdancer_path . "/$BREAKDANCER_COMMAND";
    my $cmd = "$breakdancer_path " . $self->config_output . " " . $self->_breakdancer_params . " > "  . $self->sv_output;
    $self->status_message("EXECUTING BREAKDANCER STEP: $cmd");
    my $return = Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->config_output],
        output_files => [$self->sv_output],
        allow_zero_size_output_files => 1,
    );

    unless ($return) {
        $self->error_message("Running breakdancer failed using command: $BREAKDANCER_COMMAND ");
        die;
    }

    unless (-s $self->sv_output) {
        $self->error_message("$BREAKDANCER_COMMAND output " . $self->sv_output . " does not exist or has zero size");
        die;
    }
 

    return 1;
}

sub breakdancer_path {
    my $self = $_[0];
    return $self->path_for_breakdancer_version($self->version);
}

sub available_breakdancer_versions {
    my $self = shift;
    return keys %BREAKDANCER_VERSIONS;
}

sub path_for_breakdancer_version {
    my $class = shift;
    my $version = shift;

    if (defined $BREAKDANCER_VERSIONS{$version}) {
        return $BREAKDANCER_VERSIONS{$version};
    }
    die('No path for breakdancer version '. $version);
}

sub default_breakdancer_version {
    die "default breakdancer version: $DEFAULT_VERSION is not valid" unless $BREAKDANCER_VERSIONS{$DEFAULT_VERSION};
    return $DEFAULT_VERSION;
}
 
1;
