
package Genome::Model::Command::Define::ImportedAssembly;

use strict;
use warnings;

use Genome;
use GSCApp;
use Data::Dumper;

class Genome::Model::Command::Define::ImportedAssembly {
    is => 'Genome::Model::Command::Define',
    has_optional => [
    files   => {
        is => 'Text',
        is_many => 1,
        is_optional => 1, 
        doc => 'a list of SFF files'
    },
    model_name => {
        is => 'Text',
        doc => 'model name',
    },
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define imported-assembly --subject-name <human> --subject-type <species_name>
genome model define imported-assembly --model-name <MY_MODEL_NAME> --subject-name <human> --subject-type <species_name>
genome model define imported-assembly --subject-name <unknown> --files <FULL_PATH_TO_SFF.1,FULL_PATH_TO_SFF2>
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model representing an assembly or group of assemblies of the same subject
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    return $self;
}

sub execute {
    my $self = shift;
    #DEFINE MODEL
    if (my @files = $self->files) {
        #DEFINE MODEL AND DERIVE SUBJECT NAME FROM SFF FILES
        unless ($self->_define_from_sff_files(@files)) {
            $self->error_message("Failed to define model from sff files");
            return;
        }
    }
    else {
        # run Genome::Model::Command::Define execute
        my $super = $self->super_can('_execute_body');
        return $super->($self,@_);    
    }

    return 1;
}

sub _define_from_sff_files {
    my ($self, @sffs) = @_;

    #GET LIBRARY NAMES FROM EACH SFF FILE
    my $library_names = {}; #HASH TO STORE UNIQ LIB NAMES
    foreach my $sff_file (@sffs) {
        unless (-s $sff_file) {
            $self->error_message("Invalid sff file or file does not exist: $sff_file");
            return;
        }
        my $library_name = $self->_get_library_name($sff_file);
        $library_names->{$library_name} = 1;
    }

    my $lib_name_string;
    foreach (keys %$library_names) {
        $lib_name_string .= "\t".$_."\n";
    }
    $self->status_message("\nFound the following library names\n".$lib_name_string);

    #GET SAMPLE NAMES FROM EACH LIBRARY NAME
    my @sample_names = $self->_get_sample_names(keys %$library_names);

    my $sample_name_string;
    foreach (@sample_names) {
        $sample_name_string .= "\t".$_."\n";
    }
    $self->status_message("\nFound the following sample names\n".$sample_name_string);

    #DEFINE SUBJECT NAME AND SUBJECT TYPE
    my $subject_name;
    my $subject_type;
    if (scalar @sample_names == 1) {
        #IF SINGLE SAMPLE NAME .. DEFINE MODEL USING SAMPLE NAME AS SUBJECT
        ($subject_name) = map {$_} @sample_names; #JUST ONE ELEMENT HERE ..
        $subject_type = 'sample_name';
    }
    elsif (scalar @sample_names > 1) {#MULTIPLE SAMPLE NAMES .. USE SPECIES NAME AS SUBJECT
        my $species_names = {};
        #GET SPECIES NAME FOR EACH SAMPLE NAME
        foreach my $sample_name (@sample_names) {
            my $species_name = $self->_get_species_name($sample_name);
            unless ($species_name) {
                $self->error_message("Failed to get species name for a sample name: $sample_name");
                return;
            }
            $species_names->{$species_name} = 1;
        }
        #DIE IF MULTIPLE SPECIES NAMES
        #TODO - HOW TO PROPERLY DEFINE A MODEL IF SAMPLES FROM MULTIPLE SPECIES ARE USED
        if (scalar keys %$species_names > 1) {
            $self->error_message("Multiple spceies names found ".map {"\t".$_."\n"} keys %$species_names);
            return;
        }
        ($subject_name) = map {$_} keys %$species_names; #SINGLE ELEMENT HASH
        $subject_type = 'species_name';
    }
    else { #SHOULD NEVER GET HERE
        $self->error_message("Unable to define s subject name for the model");
        return;
    }

    #CHECK IF A MODEL WITH THIS SUBJECT NAME ALREADY EXISTS
    my @model;
    @model = Genome::Model->get(
        subject_name => $subject_name,
        processing_profile_name => $self->processing_profile_name,
    );

    if (@model>0) { #EXISTING MODEL(S)
        $self->status_message("\nModel(s) with subject name $subject_name already exists. ".
            "\n\tMODEL ID: ".$model[0]->id."\n\tSUBJECT NAME: ".$model[0]->subject_name."\n\tMODEL NAME: ".$model[0]->name."\n\n".
            "It is not necessary to create new model for $subject_name, please add new data to this model using the following command:\ngenome model build start ".$model[0]->name." --data-directory=/path/to/your/assembly\n");
    }
    else { #CREATE A NEW MODEL
        $self->status_message("\nDefining model with subject name: $subject_name and subject type: $subject_type");
        $self->subject_name($subject_name);
        $self->subject_type($subject_type);
        my $super = $self->super_can('_execute_body');
        return $super->($self,@_);       
    }    
    return 1;
}

sub _get_species_name {
    my $self = shift;
    my $sample_name = shift;
    my $sample = Genome::Sample->get(name => $sample_name);
    unless ($sample and $sample->species_name) {
        $self->error_message("Failed to get species name for sample name: $sample_name");
        return;
    }
    return $sample->species_name;
}

sub _get_sample_names {
    my $self = shift;
    my @library_names = (@_);

    #THIS IS INCONSISTENT .. DOESN'T ALWAYS FIND SAMPLE NAMES
    #my $lib = Genome::Library->get(name => $lib_name);
    #my $sample_name = $lib->sample->name;    
    my @sample_names;
    foreach my $lib_name (@library_names)
    {
        my $query = 'genome instrument-data list 454 --filter library_name=\''.$lib_name.
        '\' --show sample_name --noheaders';
        push @sample_names, `$query`;
        unless (@sample_names) {
            $self->error_message("Failed to find sample name for $lib_name");
            return;
        }
    }
    chomp @sample_names;
    
    my %sample_names;
    foreach (@sample_names) {
        $sample_names{$_} = 1;
    }

    return keys %sample_names;
}

sub _get_library_name {
    my $self = shift;
    my $sff_file = shift;

    my @tmp = split('/', $sff_file);

    my ($region_number) = $tmp[-1] =~ /\w*(\d\d)\.sff$/;

    my $rr_454 = GSC::RunRegion454->get(
        run_name => $tmp[5],
        analysis_name => $tmp[6],
        region_number => $region_number,
    );

    unless ($rr_454 and $rr_454->library_name) {
        $self->error_message("Failed to get library name for following data:\n$sff_file");
        return;
    }

    return $rr_454->library_name;
}

1;

