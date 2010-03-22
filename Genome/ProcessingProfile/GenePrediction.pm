package Genome::ProcessingProfile::GenePrediction;

use strict;
use warnings;
use Genome;
use Carp;
use YAML qw( DumpFile );
use IPC::Run; # replace system()


# any param marked 'input' will eventually have to be figured out
# based on the (to be developed) model
class Genome::ProcessingProfile::GenePrediction {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    has_param => [
#        config_file => { # get rid of this?
#            doc => "yaml file for gene prediction pipeline; eventually, we'll blow this up and use the options directly...",
#        },
        cell_type => {
            doc => "one of BACTERIAL, ARCHAEA, VIRAL, CORE, or EUKARYOTIC",
            valid_values => ["BACTERIAL","ARCHAEA","VIRAL","CORE","EUKARYOTIC" ],
        },
        locus_id => { # input?
            doc => "locus tag without DFT/FNL/MSI...",
        },
        draft => {
            doc => "a three letter identifier appended to locus id, ie DFT/FNL/MSI",
            is_optional => 1,
        },
        path => {
            doc => "base path where data/files land; usually /gscmnt/278/analysis/HGMI",
        },
        brev_orgname => { # input
            doc => "abbreviated organism name; aka org_dirname",
        },
        organism_name => { # input
            doc => "organism name",
        },
        assembly_version => {
            doc => "assembly version",
        },
        pipeline_version => {
            doc => "pipeline version",
        },
        minimum_seq_length => {
            doc => "default 200 bases(?)",
        },
        acedb_version => {
            doc => "version of acedb to load to",
        },
        project_type => {
            doc => " project type",
        },
        runner_count => {
            doc => "number of runners for bap_gene_predict",
            is_optional => 1,
        }, 
        gram_stain => {
            doc => "gram stain for bacterial genomes",
            is_optional => 1,
        },
        ncbi_taxonomy_id => { # input
            doc => "ncbi taxonomy id.",
            is_optional => 1,
        },
        predict_script_location => {
            doc => "location of prediction script",
            is_optional => 1,
        },
        merge_script_location => {
            doc => "location of finish script",
            is_optional => 1,
        },
        finish_script_location => {
            doc => "location of finish script",
            is_optional => 1,
        },
        skip_acedb_parse => {
            doc => "skip acedb parsing in bap project finish",
            is_optional => 1,
        },
        seq_file_name => { # input
            doc => "usually contigs.bases",
        }, 
        seq_file_dir => { # input
            doc => "directory where contigs.bases/seq_file_name is found",
        },

    ],
    doc => "gene prediction processing profile..."
};

sub _initialize_model {
    my ($self,$model) = @_;
    carp "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    carp "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    carp "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    #my $cmd = $self->command_name;
    my $cmd = "gmt hgmi hap";
    # generate a config file here.
    my $config = $self->config_file;
#    my $args = $self->args;

    my $dir = $build->data_directory;

    # create the yaml file for now


    # instead of nasty system(), we should pull in the stuff from dir build
    # mk prediction models, collect/name sequence, bap gene predict,
    # bap gene merge, bap_project_finish, rrna screen, core gene check
    my $exit_code = system "$cmd --config $config --skip-protein-annotation  >$dir/output 2>$dir/errors";
    $exit_code /= 256;
    if ($exit_code != 0) {
        $self->error_message("Failed to run $cmd with args !  Exit code: $exit_code.");
        return;
    }

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;
    
    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

sub _create_yaml_config {
    my $self = shift;
    # pop all the params into a hash
    my $option_hash_ref;
    my $yaml_config;
    # dump the yaml file out
    DumpFile( $yaml_config ,$option_hash_ref);
    return 1;
}

1;


