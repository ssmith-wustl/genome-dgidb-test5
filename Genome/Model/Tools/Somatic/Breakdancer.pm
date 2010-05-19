package Genome::Model::Tools::Somatic::Breakdancer;

use warnings;
use strict;

use Genome;

# TODO 
# Make this more generic, make it subclass like alignments/aligner rather than always run breakdancer

my $DEFAULT_VERSION = '2010_03_02';
my $CONFIG_COMMAND = 'bam2cfg.pl';
my $BREAKDANCER_COMMAND = 'BreakDancerMax.pl';

class Genome::Model::Tools::Somatic::Breakdancer{
    is => 'Command',
    has => [
        use_version => {
            is => 'Version',
            is_optional => 1,
            is_input => 1,
            default_value => $DEFAULT_VERSION,
            doc => "Version of breakdancer to use, default is $DEFAULT_VERSION"
        },
        tumor_bam_file => {
            is => 'Text',
            is_input => 1,
            doc => "The tumor bam file to run breakdancer on"
        },
        normal_bam_file => {
            is => 'Text',
            is_input => 1,
            doc => "The normal bam file to run breakdancer on"
        },
        config_output => {
            is => 'Text',
            is_input => 1,
            is_output => 1,
            doc => "Store the breakdancer configuration in the specified file"
        },
        breakdancer_output => {
            is => 'Text',
            is_input => 1,
            is_output => 1,
            doc => "Store breakdancer output in the specified file"
        },
        breakdancer_params => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            default_value => "",
            doc => "Parameters to pass to breakdancer, default to none",
        },
        bam2cfg_params => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            default_value => "",
            doc => "Parameters to pass to bam2cfg, default to none",
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
};


# HACK HACK HACK HACK WARNING THIS IS A HORRIBLE HACK 
# workflow passes in an empty string for use version if the value is undef
# but empty string can't resolve to a version, so stuff the default one in 
# while creating.
################################################
sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
   
    if ($self->use_version eq "") {
        $self->use_version($DEFAULT_VERSION);
    }

    return $self; }

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
gmt somatic breakdancer -t tumor.bam -n normal.bam --config-output config.out --breakdancer-output breakdancer.out
gmt somatic breakdancer -t tumor.bam -n normal.bam -c config.out -b breakdancer.out --use-version 0.0.1r59 --skip-if-output-present 
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
    if (($self->skip_if_output_present)&&(-s $self->breakdancer_output)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    $self->run_config;

    $self->run_breakdancer;

    return 1;
}

sub run_config {
    my $self = shift;

    my $config_path = $self->breakdancer_path . "/$CONFIG_COMMAND";
    my $cmd = "$config_path " . $self->tumor_bam_file . " " . $self->normal_bam_file . " " . $self->bam2cfg_params . " > "  . $self->config_output;
    $self->status_message("EXECUTING CONFIG STEP: $cmd");
    my $return = system($cmd);

    unless ($return == 0) {
        $self->error_message("$CONFIG_COMMAND returned a nonzero code of $return");
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
    my $cmd = "$breakdancer_path " . $self->config_output . " " . $self->breakdancer_params . " > "  . $self->breakdancer_output;
    $self->status_message("EXECUTING BREAKDANCER STEP: $cmd");
    my $return = system($cmd);

    unless ($return == 0) {
        $self->error_message("$BREAKDANCER_COMMAND returned a nonzero code of $return");
        die;
    }

    unless (-s $self->breakdancer_output) {
        $self->error_message("$BREAKDANCER_COMMAND output " . $self->breakdancer_output . " does not exist or has zero size");
        die;
    }
 

    return 1;
}

sub breakdancer_path {
    my $self = $_[0];
    return $self->path_for_breakdancer_version($self->use_version);
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
