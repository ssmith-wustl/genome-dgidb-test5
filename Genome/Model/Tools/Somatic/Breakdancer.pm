package Genome::Model::Tools::Somatic::Breakdancer;

use warnings;
use strict;

use Genome;

# TODO 
# Make this more generic, make it subclass like alignments/aligner rather than always run breakdancer

my $DEFAULT_VERSION = '0.0.1r59';
my $CONFIG_COMMAND = 'bam2cfg.pl';
my $BREAKDANCER_COMMAND = 'BreakDancerMax.pl';

class Genome::Model::Tools::Somatic::Breakdancer{
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT_VERSION, doc => "Version of breakdancer to use, default is $DEFAULT_VERSION" },
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
};

my %BREAKDANCER_VERSIONS = (
	'0.0.1r59' => '/gsc/scripts/pkg/bio/breakdancer/breakdancer-0.0.1r59',
);

sub help_brief {
    "discovers structural variation using breakdancer",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools breakdancer...    
EOS
}

sub help_detail {                           
    return <<EOS 
discovers structural variation using breakdancer
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
    my $return = system("$config_path " . $self->tumor_bam_file . " " . $self->normal_bam_file ." > "  . $self->config_output);

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
    my $return = system("$breakdancer_path " . $self->config_output ." > "  . $self->breakdancer_output);

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
    die "default samtools version: $DEFAULT_VERSION is not valid" unless $BREAKDANCER_VERSIONS{$DEFAULT_VERSION};
    return $DEFAULT_VERSION;
}
 
1;
