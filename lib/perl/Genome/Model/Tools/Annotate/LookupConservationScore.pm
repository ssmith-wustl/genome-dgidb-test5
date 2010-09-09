package Genome::Model::Tools::Annotate::LookupConservationScore;

use strict;
use warnings;
use Genome;
use IO::File;
use Genome::Info::UCSCConservation;

class Genome::Model::Tools::Annotate::LookupConservationScore{
    is => 'Genome::Model::Tools::Annotate',
    has => [
        chromosome => {
            is => 'Text',
            is_input => 1,
            doc => "Name of the chromosome where the coordinates reside", 
            is_optional => 0,
        },
        coordinates => {
            is => 'Text',
            is_input => 1,
            doc => "Coordinates in the chromosome to check.  Should come in the form of a string or array of positions (ex: (1, 2, 3, 4, 5))", 
            is_optional => 0,
        },
        species => {
            is => 'Text',
            is_input => 1,
            doc => "Species used for scoring.  Species and version must be specified unless reference_transcripts is specified", 
            is_optional => 1,
        },
        version=> {
            is => 'Text',
            is_input => 1,
            doc => "Version of the species used for scoring.  Must be in a form like 54_36p.  Species and version must be specified unless reference_transcripts is specified", 
            is_optional => 1,
        },
        reference_transcripts =>{
            is => 'Text',
            is_input => 1,
            doc => "model name and version used for scoring (ex: NCBI-human.combined-annotation/54_36p).  reference_transcripts must be specified unless species and version are specified", 
            is_optional => 1,
        },
        conservation_scores_results => {
            is => 'SCALAR', 
            is_output => 1,
            doc => "This is populated with an array reference containing the results of the conservation score lookup post execute",
            is_optional => 1,
        }
    ],
};

sub help_synopsis {
    return <<EOS
my \$lookup = Genome::Model::Tools::Annotate::LookupConservationScore->execute(chromosome => 1, coordinates => '(1, 2, 3)', species => 'human', version => '54_36p_v2');
my \$results_array_ref = \$lookup->conservation_scores_results;
EOS
}

sub execute{

    my $self = shift; 
    my ($chromosome, $coordinates_ref);
    $chromosome = $self->chromosome;

    if(ref($self->coordinates) eq 'ARRAY'){
        $coordinates_ref = $self->coordinates;
    }else{
        $self->error_message("Malformed coordinates.  Coordinates should be specified as an array ref");
        return 0;
    }
    
    my ($model_name, $version, $build_version);
    if($self->reference_transcripts and $self->species and $self->version){
        $self->error_message("species and version OR reference_transcripts must be specified");
        return 0;
    }elsif($self->reference_transcripts){
        ($model_name, $build_version) = split("/", $self->reference_transcripts); 
        $build_version =~ m/[\d]+_([\d]+)[a-zA-Z]/ or die "Malformed reference_transcripts: $model_name/$build_version";
        $version = $1;
    }elsif($self->species and $self->version){
        $model_name = "NCBI-" . $self->species . ".combined-annotation";
        if($self->version =~ m/[\d]+_([\d]+)[a-zA-Z]/){
            $version = $1; 
            $build_version = $self->version;
        }else{
            die "Malformed version: " . $self->version;
        }

    }else{
        $self->error_message("species and version OR reference_transcripts must be specified");
        return 0;
    }

    #TODO: Remove these restrictions as soon as possible
    unless($model_name eq 'NCBI-human.combined-annotation'){
        $self->error_message("Cannot look up conservation scores for model: $model_name.  This module currently supports the following models: NCBI-human.combined-annotation"); 
        return 0;
    }
    unless($version == 36 or $version == 37){
        $self->error_message("Cannot look up conservation scores for model $model_name version $version.  This module currently supports the following versions for $model_name: 36, 37"); 
        return 0;
    }

    my $model = Genome::Model->get(name => $model_name); 
    die "Could not get model $model_name: $!" unless $model;
    my $build = $model->build_by_version($build_version);
    die "Could not get $model_name build for version $build_version: $!" unless $build;

    #TODO: This will need to change to support conservation dirs that have
    #been sym linked to the build dirs
    my %location_index = Genome::Info::UCSCConservation->ucsc_conservation_directories;
    my $location = $location_index{$version};

    #TODO: we're copying directly from MG/ConsScore.pm from this point on.  It probably sucks and
    #needs to be refactored
    my @results;
    my $file = $location . "/chr".$chromosome."-rec";
    # open file, 
    my $fh = new IO::File;
    if(!exists($self->{_file_handles}->{$chromosome} ) )
    {
        $self->{_file_handles}->{$chromosome} = $fh;
        $fh->open($file) or die "can't open $file : $!";
    }
    else
    {
        $fh = $self->{_file_handles}->{$chromosome};
    }
    @$coordinates_ref = sort { $a <=> $b } @$coordinates_ref;
    foreach my $pos (@{$coordinates_ref})
    {
        # start seeking until the first position
        $fh->seek(($pos -1)*2,0);
        my $tmpval;
        $fh->read($tmpval,2);
        # unpack value, divide by 1000 and push onto array.
        my $score = unpack("n",$tmpval)/1000;
        push(@results, [ $pos, $score ]);
    }
    # return array ref of array refs of positions, scores?
    $fh->close;
    $self->conservation_scores_results(\@results);
    return  1;
}

1;
