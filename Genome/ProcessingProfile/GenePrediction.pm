package Genome::ProcessingProfile::GenePrediction;

use strict;
use warnings;
use Genome;
use Carp;
use YAML qw( DumpFile );
use IPC::Run; # replace system()
use File::Slurp;


# any param marked 'input' will eventually have to be figured out
# based on the (to be developed) model
class Genome::ProcessingProfile::GenePrediction {
    is => 'Genome::ProcessingProfile',
    has => [
        # TODO: this is in the base class, and should not really run inline for this subclass
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        # TODO: this is in the base class, and should not really run inline for this subclass
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
#       # TODO: derive from the taxon's domain field.  Note that is not all-upercase there so there may be some other changes to do.
        cell_type => {
            doc => "one of BACTERIAL, ARCHAEA, VIRAL, CORE, or EUKARYOTIC",
            valid_values => ["BACTERIAL","ARCHAEA","VIRAL","CORE","EUKARYOTIC" ],
        },
#        locus_id => { # input?
#            doc => "locus tag without DFT/FNL/MSI...",
#        },
        draft => {
            doc => "a three letter identifier appended to locus id, ie DFT/FNL/MSI",
            is_optional => 1,
        },
        # TODO: this should all go into the build directory now
        path => {
            doc => "base path where data/files land; example /gscmnt/278/analysis/HGMI",
        },
#        brev_orgname => { # input
#            doc => "abbreviated organism name; aka org_dirname",
#        },
#        organism_name => { # input
#            doc => "organism name",
#        },
#       # TODO: this model links to an assembly model, and should be a model input, not in the PP
        assembly_version => {
            doc => "assembly version",
        },
        # TODO: what is this?
        pipeline_version => {
            doc => "pipeline version",
        },
        minimum_seq_length => {
            doc => "minimum contig sequence length; when in doubt set to 200",
        },
        acedb_version => {
            doc => "version of acedb to load to",
        },
        # TODO: what is this, and what does it mean?
        project_type => {
            doc => " project type",
        },
        # TODO: this is okay enough, but ideally params which do not affect results should not be here
        runner_count => {
            doc => "number of runners for bap_gene_predict",
            is_optional => 1,
        }, 
        # TODO: this is okay now, but should ultimately come from a new column on the Genome::Taxon
        gram_stain => {
            doc => "gram stain for bacterial genomes",
            is_optional => 1,
        },
#        ncbi_taxonomy_id => { # input
#            doc => "ncbi taxonomy id.",
#            is_optional => 1,
#        },
        # TODO: see what these are and if they are used
        predict_script_location => {
            doc => "location of prediction script",
            is_optional => 1,
        },
        # TODO: see what these are and if they are used
        merge_script_location => {
            doc => "location of finish script",
            is_optional => 1,
        },
        # TODO: see what these are and if they are used
        finish_script_location => {
            doc => "location of finish script",
            is_optional => 1,
        },
        skip_acedb_parse => {
            doc => "skip acedb parsing in bap project finish",
            is_optional => 1,
        },
        dev => {
            doc => "use development database",
            is_optional => 1,
            default => 0,
        },
#        seq_file_name => { # input
#            doc => "usually contigs.bases",
#        }, 
#        seq_file_dir => { # input
#            doc => "directory where contigs.bases/seq_file_name is found",
#        },

        #assembly_model => {
        #    via => 'assembly_model_links'
        #}
    ],
    doc => "gene prediction processing profile..."
};

# TODO: this probably should be deleted
sub _initialize_model {
    my ($self,$model) = @_;
    carp "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    # should figure out a few things here - grab the paths for the different files and so on.
#    $model->add_from_model(from_model => $model->assembly_model, role => 'assembly_model');

    return 1;
}

# TODO: this probably should be deleted
sub _initialize_build {
    my ($self,$build) = @_;
    carp "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
#    unless( -f $build->yaml_file() )
#    {
#        $build->status_message("YAML file exists");
        $build->status_message("creating yaml file");
        $build->_create_yaml_file();
#    }

    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    carp "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    # THE "gmt hgmi" namespace should probably not exist.
    # Modules
    #my $cmd = $self->command_name;
    my $cmd = "gmt hgmi hap";
    # generate a config file here.
    my $config = $build->yaml_file();

    my $dir = $build->data_directory;

    my $exit_code;
    if($self->dev) {
        $exit_code = system "$cmd --dev --config $config --skip-protein-annotation  >$dir/output 2>$dir/errors";
        write_file("$dir/errors",{append=>1},"exit code: $exit_code\n");
    }
    else
    {
        $exit_code = system "$cmd --config $config --skip-protein-annotation  >$dir/output 2>$dir/errors";
        write_file("$dir/errors",{append=>1},"exit code: $exit_code\n");
    }
    $exit_code /= 256;
    if ($exit_code != 0) {
        $self->error_message("Failed to run $cmd with args !  Exit code: $exit_code.");
        croak;
        # problems when we return on non-zero exit code.  builds that should be marked fail
        # end up getting marked as succeeded.
        #return;
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

#sub _create_yaml_config {
#    my $self = shift;
#    # pop all the params into a hash
#    my $option_hash_ref;
#    #
#    my $yaml_config;
#    # dump the yaml file out
#    DumpFile( $yaml_config ,$option_hash_ref);
#    return 1;
#}

1;


