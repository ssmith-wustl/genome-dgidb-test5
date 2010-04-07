# FIXME ebelter
#  Long: remove this and all define modules to have just one that can handle model inputs
package Genome::Model::Command::Define::ImportedReferenceSequence;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::ImportedReferenceSequence {
    is => 'Genome::Model::Command::Define',
    has => [
        fasta_file =>
        {
            is => 'Text',
            len => 1000,
            doc => "The full path and filename of the reference sequence fasta file to import."
        }
    ],
    has_optional => [
        model_name => {
            is => 'Text',
            len => 255,
            doc => '$PREFIX-$SPECIES_NAME unless otherwise specified.'
        },
        prefix => {
            is => 'Text',
            doc => 'The source of the sequence, such as "NCBI".  May not have spaces.'
        },
        species_name => {
            is => 'Text',
            len => 64,
            doc => 'The species name of the reference.  This value must correspond to a species name found in the gsc.organism_taxon table.'
        },
        version => {
            is => 'Text',
            len => 128,
            doc => 'The version number and/or description of the reference.  May not have spaces.  This may be, for example '.
                   '"37" or "37_human_contamination".'
        },
        on_warning => {
            valid_values => ['prompt', 'exit', 'continue'],
            default_value => 'prompt',
            doc => 'The action to take when emitting a warning.'
        },
        job_dispatch => {
#            default_value => 'apipe',
#            is_constant => 1,
            doc => 'dispatch specification: an LSF queue or "inline"'
        },
        server_dispatch => {
#            default_value => 'long',
#            is_constant => 1,
            doc => 'dispatch specification: an LSF queue or "inline"',
        },
   ],
};

sub help_synopsis {
    return "Prepares a fasta file to be used as a new refseq in processing profiles";
}

sub help_detail {
    return "Copies a fasta file out to the reference path, and then schedules jobs which will " . 
           "create appropriate BWA, Maq, and Samtools index files."
}

use Exception::Class('ImportedReferenceSequenceException');

sub onErr
{
    my $str = shift @_;
    ImportedReferenceSequenceException->throw('error' => $str);
}

sub onCheck
{
    my $str = shift @_;
    print STDERR $str . "  Go ahead anyway?  (type yes and press enter to do so).\n";
    my $in = <STDIN>;
    if(defined($in))
    {
        chomp $in;
        if($in eq 'yes')
        {
            onWarn($str);
            return;
        }
    }
    ImportedReferenceSequenceException->throw('error' => $str);
}

sub onWarn
{
    my $str = shift @_;
    print STDERR 'Ignoring error: ' . $str . "\n";
}

# Default to bombing out with an error description upon fatal exception
my $err = \&onErr;
# Default to prompting for "yes\n" from stdin upon warning
my $check = \&onCheck;

sub _execute_try {
    my ($self, $news) = @_;
    if(defined($self->prefix) && $self->prefix =~ /\s/)
    {
        $err->("The prefix argument value must not contain spaces.");
    }

    unless(defined($self->model_name) || defined($self->species_name))
    {
        $err->("Either model name or species name must be supplied.  For a new model, species name is always required.");
    }

    # * Verify that model attributes we generate were not supplied by the caller
    my $errStr = "";
    foreach grep( {eval 'defined $self->' . $_} ('data_directory', 'processing_profile_name', 'subject_type', 'subject_id', 'subject_class_name') )
    {
        if(length($errStr) > 0)
        {
            $errStr .= "\n";
        }
        $errStr .= "$_ is generated automatically and must not be specified for an imported reference sequence.";
    }
    if(length($errStr) > 0)
    {
        $err->($errStr);
    }
    undef $errStr;

    # * Verify that species name matches a taxon
    my $taxon;
    if(defined($self->species_name))
    {
        my @taxons = Genome::Taxon->get('species_name' => $self->species_name);
        if($#taxons == -1)
        {
            $err->("No Genome::Taxon found with species name \"" . $self->species_name "\".");
            return;
        }
        if($#taxons > 0)
        {
            $err->("Multiple Genome::Taxon instances found with species name \"" . $self->species_name "\".  This code was written " .
                   "with the assumption that species name uniquely identifies each Genome::Taxon instance.  If strain name or " .
                   "another other field is required in addition to species name to uniquely identify some Genome::Taxon instances, " .
                   "this code should be updated to take strain name or whatever other field as an argument in addition to " .
                   "species name.");
            return;
        }
        $taxon = $taxons[0];
    }

    # * Generate a model name if one was not provided
    unless(defined($self->model_name))
    {
        my $transformedSpeciesName = $self->species_name;
        $transformedSpeciesName =~ s/\s/_/g;
        $self->model_name($self->prefix . '-' . $transformedSpeciesName);
    }

    # * Make a model if one with the appropriate name does not exist.  If one does, check whether making a build for it would duplicate an
    #   existing build.
    my @models = Genome::Model->get('name' => $self->model_name);
    my $model;
    if($#models > 0)
    {
        $err->("More than one model (" . $#models . ") found with the name \"" . $self->model_name . "\".");
    }
    elsif($#models == 0)
    {
        # * We're going to want a new build for an existing model, but first we should see if there are already any builds
        #   of the same version for the existing model.  If so, we ask the user to confirm that they really want to make another.
        $model = $models[0];
        if($model->type_name ne 'imported reference sequence')
        {
            $err->("A model with the name \"" . $self->model_name . "\" already exists and is not an imported reference sequence.");
        }
        if(defined($taxon) && ($model->subject_class_name ne 'Genome::Taxon' || $model->subject_id != $taxon->taxon_id))
        {
            $err->("A model with the name \"" . $self->model_name . "\" already exists but has a different subject class name or a " .
                   "subject ID other than that corresponding to the species name supplied.");
        }
        unless(defined($self->version))
        {
            $check->("A model of name \"" . $model->name "\" exists and imported reference version was not specified.");
        }
        my @builds = grep( defined($self->version) ? {defined($_->version) && $_->version eq $self->version} : {!defined($_->version)},
                           Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence') );
        if($#builds > -1)
        {
            my $errStr = 'The ';
            if($#builds > 0)
            {
                $errStr .= 'builds of ids [' . join(', ', map({$_->build_id}, @builds)) . '] of this model have the same version identifier.';
            }
            else
            {
                $errStr .= 'build of id ' . $builds[0]->build_id . ' of this model has the same version identifier.';
            }
            $check->($errStr);
        }
    }
    else
    {
        # * We need a new model
        %modelParams = ('subject_type' => 'species_name',
                        'subject_name' => $self->species_name,
                        'subject_class_name' => 'Genome::Taxon',
                        'subject_id' => $taxon->taxon_id,
                        'processing_profile_id' => $self->_get_processing_profile_id_for_name,
                        'name' => $self->model_name);
        if(defined($self->version))
        {
            $modelParams{'version'} = $self->version;
        }
        $model = Genome::Model->create(%modelParams);
        unless($model)
        {
            $err->("Failed to create model.");
        }
        push @$news, $model;
        if(my @problems = $model->__errors__)
        {
            $err->( "Error creating model:\n\t".  join("\n\t", map({$_->desc} @problems)) );
        }
    }
    undef @models;

    # * Create the build
    my $cmd = "genome model build create " . $model->genome_model_id;
    $cmd .= ' --server-dispatch "' . $self->server_dispatch . '"' if(defined($self->server_dispatch));
    $cmd .= ' --job-dispatch "' . $self->job_dispatch . '"' if(defined($self->job_dispatch));
    unless(system($cmd) == 0)
    {
        $err->("Failed to create build for model " . $model->genome_model_id . ".");
    }
}

sub execute {
    my $self = shift;
    my @news;
    eval
    {
        if(!defined($self->on_warning))
        {
            $err->('on_warning parameter not supplied.');
        }

        if($self->on_warning eq 'prompt')
        {
            $err = \&onErr;
            $check = \&onCheck;
        }
        elsif($self->on_warning eq 'exit')
        {
            $err = \&onErr;
            $check = \&onErr;
        }
        elsif($self->on_warning eq 'continue')
        {
            $err = \&onErr;
            $check = \&onWarn;
        }
        else
        {
            $err->('on_warning parameter value "' . $self->on_warning . '" not supported.');
        }

        $self->_execute_try(\@news);
    }
    if(my $e = Exception::Class->caught('ImportedReferenceSequenceException'))
    {
        my $new;
        foreach $new (@news)
        {
            $new->delete();
        }
        $self->error_message($exceptionstring);
        return;
    }

    return 1;

#
#   my @new;
#   # if it does not exist
#       # ensure species is specified, tell them to select one
#       # get the species, and ensure it is valid/real
#       # make a model with that Genome::Taxon as the "subject"
#       # use the single existing processing profile, named "imported reference", like the type_name
#       my $m = Genome::Model->create();
#       push @new, $m;
#
#   # set the model's external_version_number and input_filename
#   my $b = Genome::Model::Build->create(model => $m);
#   unless ($b) {
#       $self->error_message("Failed to generate a new build for model "
#                            . $m->__display_name__ . "!"
#                            . Genome::Model::Build->error_message()
#       );
#       for (@new) { $_->delete }
#       return;
#   }
#   $b->succeeded();
}

1;
