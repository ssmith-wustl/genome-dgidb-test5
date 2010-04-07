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
        }
   ],
};

sub help_synopsis {
    return "Prepares a fasta file to be used as a new refseq in processing profiles";
}

sub help_detail {
    return "Copies a fasta file out to the reference path, and then schedules jobs which will " . 
           "create appropriate BWA, Maq, and Samtools index files."
}

sub execute {
    my @news;
    eval
    {
        my $self = shift;
    
        if(defined($self->prefix) && $self->prefix =~ /\s/)
        {
            $self->error_message("The prefix argument value must not contain spaces.");
            return;
        }
    
        unless(defined($self->model_name) || defined($self->species_name))
        {
            $self->error_message("Either model name or species name must be supplied.  For a new model, species name is always required.");
        }
    
        # * Verify that model attributes we generate were not supplied by the caller
        my $err = "";
        foreach grep( {eval 'defined $self->' . $_} ('data_directory', 'processing_profile_name', 'subject_type', 'subject_id', 'subject_class_name') )
        {
            if(length($err) > 0)
            {
                $err .= "\n";
            }
            $err .= "$_ is generated automatically and must not be specified for an imported reference sequence.";
        }
        if(length($err) > 0)
        {
            $self->error_message($err);
            return;
        }
        undef $err;
    
        # * Verify that species name matches a taxon
        my $taxon;
        if(defined($self->species_name))
        {
            my @taxons = Genome::Taxon->get('species_name' => $self->species_name);
            if($#taxons == -1)
            {
                $self->error_message("No Genome::Taxon found with species name \"" . $self->species_name "\".");
                return;
            }
            if($#taxons > 0)
            {
                $self->error_message("Multiple Genome::Taxon instances found with species name \"" . $self->species_name "\".  This code was written " .
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
    
        # * We do different things depending on whether a model for this reference already exists
        my @models = Genome::Model->get('name' => $self->model_name);
        my $model;
        if($#models > 0)
        {
            $self->error_message("More than one model (" . $#models . ") found with the name \"" . $self->model_name . "\".");
            return;
        }
        elsif($#models == 0)
        {
            # * We're going to want a new build for an existing model, but first we should see if there are already any builds
            #   of the same version for the existing model.  If so, we ask the user to confirm that they really want to make another.
            $model = $models[0];
            if($model->type_name ne 'imported reference sequence')
            {
                $self->error_message("A model with the name \"" . $self->model_name . "\" already exists and is not an imported reference sequence.");
                return;
            }
            if(defined($taxon) && ($model->subject_class_name ne 'Genome::Taxon' || $model->subject_id != $taxon->taxon_id))
            {
                $self->error_message("A model with the name \"" . $self->model_name . "\" already exists but has a different subject class name or a " .
                                     "subject ID other than that corresponding to the species name supplied.");
                return;
            }
            unless(defined($self->version))
            {
                print STDERR "Are you sure that you want to make a new build for an existing model (of name \"" . $model->name . "\") without " .
                             "specifying an imported reference version?  Type yes and press enter if you are.\n";
                my $in = <STDIN>;
                if($in)
                {
                    chomp $in;
                    if($in ne 'yes')
                    {
                        self->error_message("A model of name \"" . $model->name "\" exists and imported reference version was not specified.");
                        return;
                    }
                }
            }
            my @builds = grep( defined($self->version) ?
                                   {defined($_->version) && $_->version eq $self->version} :
                                   {!defined($_->version)},
                               Genome::Model::Build::ImportedReferenceSequence->get(
                                   type_name => 'imported reference sequence'
                                   sql => "select gmb.build_id from genome_model_build gmb \n" .
                                                                                           "join genome_model gm on gmb.model_id = gm.genome_model_id \n" .
                                                                                           "join processing_profile pp on gm.processing_profile_id = pp.id \n" .
                                                                                           "where pp.type_name = 'imported reference sequence' and \n" .
                                                                                           "gm.genome_model_id = " . $model->genome_model_id) . "\n" .
                                                                                           "order by gmb.build_id" );
            if($#builds > -1)
            {
                my $warna = 'The ';
                my $warnb;
                if($#builds > 0)
                {
                    $warna .= 'builds of ids [' . join(', ', map({$_->build_id}, @builds)) . '] of this model have the same version identifier.';
                    $warnb = 'Are you sure that you want to create yet another build with the same version identifier for this model?';
                }
                else
                {
                    $warna .= 'build of id ' . $builds[0]->build_id . ' of this model has the same version identifier.';
                    $warnb = 'Are you sure that you want to create another build with the same version identifier for this model?';
                }
                print STDERR $warna . '  ' . $warnb . "  Type yes and press enter if you are.\n";
                my $in = <STDIN>;
                if($in)
                {
                    chomp $in;
                    if($in ne 'yes')
                    {
                        self->error_message($warna);
                        return;
                    }
                }
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
                $self->error_message('Failed to create model.');
                return;
            }
            if(my @problems = $model->__errors__)
            {
                $self->error_message( "Error creating model:\n\t".  join("\n\t", map({$_->desc} @problems)) );
                $model->delete;
                return;
            }
        }
        undef @models;
    }
    if(exception)
    {
        foreach (@news)
        {

        }
        $self->error_message($exceptionstring);
        return;
    }

    return 1;

    
    $self->subject_type = 'species_name';
    $self->subject_name = $self->species_name;
    $self->subject_class_name = 'Genome::Taxon';
    $self->subject_id = $taxon->taxon_id;

    # check to see if the model exists


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
