
package Genome::Model::Command::Define::ImportedAssembly;

use strict;
use warnings;

use Genome;
use File::Basename;
use Data::Dumper;

class Genome::Model::Command::Define::ImportedAssembly {
    is => 'Genome::Model::Command::Define::Helper',
    has_optional => [
        sff_files => {
            is => 'Text',
            is_many => 1,
            is_optional => 1, 
            doc => 'a comma separated list of SFF files',
        },
        sff_dir => {
            is => 'Text',
            is_optional => 1,
            doc => 'a newbler sff files directory',
        },
        exclude_sff_files => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'a comma separated list of SFF files to ignore in defining model',
        },
        model_name => {
            is => 'Text',
            doc => 'model name',
        },
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define imported-assembly --processing-profile-name 'imported velvet assembly' --subject-name human 
genome model define imported-assembly --processing-profile-name 'imported velvet assembly' --subject-name "Escherichia coli 185-1" --model-name hmp-ecoli-HMPREF9549
genome model define imported-assembly --processing-profile-name 'imported velvet assembly' --subject-name H_KT-185-1-0089515594    --model-name hmp-ecoli-HMPREF9549
genome model define imported-assembly --processing-profile-name 'imported newbler assembly' --subject-name H_KT-185-1-0089515594    
genome model define imported-assembly --processing-profile-name 'imported newbler assembly' --sff-dir <FULL_PATH_TO_SFF_LINKS>
genome model define imported-assembly --processing-profile-name 'imported pcap assembly' --subject-name unknown --sff-files <FILE1.SFF,FILE2.SFF>
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

    if (my @files = $self->sff_files) {
        unless ($self->_define_from_sff_files(@files)) {
            $self->error_message("Failed to define model from sff files");
            return;
        }
    }
    elsif (my $sff_dir = $self->sff_dir) {
	unless ($self->_define_from_sff_dir($self->sff_dir)) {
	    $self->error_message("Failed to define model from sff dir");
	    return;
	}
    }
    else {
        my $super = $self->super_can('_execute_body');
        return $super->($self,@_);    
    }

    return 1;
}

sub _define_from_sff_dir {
    my ($self, $sff_dir) = @_;
    
    my @sff_files = glob("$sff_dir/*.sff");
    unless (@sff_files) {
	$self->error_message("Sff link dir does not contain any sff files: $sff_dir");
	return;
    }

    unless ($self->_define_from_sff_files(@sff_files)) {
	$self->error_message("Failed to define model from sff files");
	return;
    }

    return 1;
}

sub _define_from_sff_files {
    my ($self, @sffs) = @_;

    my %species_names;
    my %sample_names;

    my @sffs_to_ignore;
    @sffs_to_ignore = $self->exclude_sff_files;

    foreach my $sff (@sffs) {
	my $sff_name = basename $sff;

	if (@sffs_to_ignore and grep (/^$sff_name$/, @sffs_to_ignore)) {
	    $self->status_message("Ignoring $sff");
	    next;
	}

	my ($univ_acc, $region_num) = $sff_name =~ /(\w{7})(\d\d)\.sff/;
	unless ($univ_acc and $region_num) {
	    $self->error_message("Failed to get universal accession and region number from sff file name: $sff_name");
	    return;
	}
	my @runs = GSC::AnalysisRun454->get( universal_accession => $univ_acc);
	unless (@runs) {
	    $self->error_message("Failed to get AnalysisRun454 object for universal accession: $univ_acc");
	    return;
	}
	my $run_name = $runs[0]->run_name;
	#MAYBE CHECK TO MAKE SURE ALL RUN OBJECTS ARE FROM SAME RUN NAME??
	#CHECKED A BUNCH AND THAT SEEMS TO BE THE CASE
	my $rr = GSC::RunRegion454->get(run_name => $run_name, region_number => $region_num);
	unless ($rr) {
	    $self->error_message("Failed to get RunRegion454 object for run name: $run_name, region number: $region_num");
	    return;
	}
	#RESOLVE SAMPLE NAME
	my $sample_name = $rr->derive_sample_name;
	unless ($sample_name) {
	    $self->error_message("Failed to derive sample name from RunRegion454 object: run name: $run_name, region number: $region_num");
	    return;
	}
	$sample_names{$sample_name} = 1 unless exists $sample_names{$sample_name};
	#RESOLVE SPECIES NAMES
	my $sample = Genome::Sample->get(name => $sample_name);
	my $species_name = $sample->species_name;
	unless ($species_name) {
	    $self->error_message("Failed to derive species name from RunRegion454 object: run name: $run_name, region number: $region_num");
	    return;
	}
	$species_names{$species_name} = 1 unless exists $species_names{$species_name};
	#CHECK FOR MULTIPLE SPECIES NAMES
	if (scalar keys %species_names > 1) {
	    my $species_names_string;
	    foreach (sort keys %species_names) {
		$species_names_string .= "\t".$_."\n";
	    }
	    $self->error_message("Found multiple species names: \n".$species_names_string);
	    #SHOULD THIS BE OKAY?  ASSEMBLING DATA FROM MULTIPLE SPECIES??
	    return;
	}
    }
    #PRINT SAMPLES NAMES FOUND FOR USER
    my $sample_names_string;
    foreach (sort keys %sample_names) {
	$sample_names_string .= "\t".$_."\n";
    }
    $self->status_message("\nFound the following sample names\n".$sample_names_string);
    #DEFINE A MODEL
    my $subject_type;
    my $subject_name;
    #IF SINGLE SAMPLE NAME USE THAT FOR SUBJECT TYPE TO DEFINE A MODEL
    if (scalar keys %sample_names == 1) {
        ($subject_name) = map {$_} keys %sample_names; #JUST ONE ELEMENT HERE ..
        $subject_type = 'sample_name';	
    }
    #IF MULTIPLE SAMPLE NAME, USE SPECIES NAME AS SUBJECT TYPE
    else {
	($subject_name) = map {$_} keys %species_names;
	$subject_type = 'species_name';
    }
    #CHECK FOR EXISTING MODELS
    my @model;
    @model = Genome::Model->get(
        subject_name => $subject_name,
        processing_profile_name => $self->processing_profile_name,
	);
    if (@model > 0) { #EXISTING MODEL(S)
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

1;

