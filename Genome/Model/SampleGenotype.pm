package Genome::Model::SampleGenotype;

use strict;
use warnings;

use IO::File;
use above "Genome";
use Data::Dumper;
use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;

class Genome::Model::SampleGenotype{
    is => 'Genome::Model::Composite',
    has => [
        hq_gfh  => {
            is  =>'IO::Handle',
            doc =>'hq genotype file handle',
            is_optional => 1,
        },
        lq_gfh  => {
            is  =>'IO::Handle',
            doc =>'lq genotype file handle',
            is_optional => 1,
        },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    my $model_dir = $self->model_directory();

    unless (-e $model_dir) {
        unless (system("mkdir $model_dir") == 0) {
            $self->error_message("Failed to mkdir model dir: $model_dir");
            die;
        }
    }

    return $self;
}

# The file containing the genotype for this sample
sub hq_genotype_file {
    my $self = shift;
    return $self->model_directory . "/hq_genotype.tsv";
}

sub lq_genotype_file {
    my $self = shift;
    return $self->model_directory . "/lq_genotype.tsv";
}

# Check to make sure all child types are valid types
sub is_valid_child{
    my ($self, $child) = @_;
    return undef unless grep { $_ eq $child->type } $self->valid_types;
}

# The valid children types for this composite
sub valid_types{
    my $self= shift;
    return qw( polyscan polyphred );
}

# Returns current directory where the microarray data is housed
sub base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/sample_genotype/';
}

sub _is_valid_child{
    my ($self, $child) = @_;
    return grep { $child->type =~ /$_/i } $self->valid_child_types;
}

sub valid_child_types{
    my $self = shift;
    return qw/polyscan polyphred/;
}

# Returns the current directory where this model is housed
# Should work for all submodules
sub model_directory {
    my $self = shift;

    # Replace all spaces with underbars to insure proper directory access
    my $name = $self->name;
    $name =~ s/ /_/g;

    return $self->base_directory . "/$name/";
}

# Returns the parameterized model associated with this composite
# Right now, bomb out if we get more than 1
sub get_models_for_type {   
    my ($self, $type) = @_;

    my @children = $self->child_models;

    my @models = grep { $_->type eq $type } @children;

    return @models;
}

# Get the polyscan model associated with this model
sub polyscan_models {
    my $self = shift;

    return $self->get_models_for_type('polyscan');
}

# Get the polyphred model associated with this model
sub polyphred_models {
    my $self = shift;

    return $self->get_models_for_type('polyphred');
}

sub hq_polyphred_model {
    my $self = shift;
    #TODO
}

sub lq_polyphred_model {
    my $self = shift;
    #TODO
}

sub hq_polypscan_model {
    my $self = shift;
    #TODO
}

sub lq_polyscan_model {
    my $self = shift;
    #TODO
}

sub next_or_undef{
    my ($self, $model) = @_;
    return undef unless $model;
    return $model->next_genotype;
}

sub combine_variants{ 
    my $self = shift;

    my $hq_genotype_file = $self->hq_genotype_file;
    my ($hq_polyscan_model) = $self->hq_polyscan_model;
    my ($hq_polyphred_model) = $self->hq_polyphred_model;
    $self->combine_variants_for_set($hq_polyscan_model, $hq_polyphred_model, $hq_genotype_file);
    
    my $lq_genotype_file = $self->lq_genotype_file;
    my ($lq_polyscan_model) = $self->lq_polyscan_model;
    my ($lq_polyphred_model) = $self->lq_polyphred_model;
    $self->combine_variants_for_set($lq_polyscan_model, $lq_polyphred_model, $lq_genotype_file);
}
    
sub combine_variants_for_set{
    my ($self, $polyscan_model, $polyphred_model, $genotype_file) = @_;
    
    my $ofh = IO::File->new("> $genotype_file");
    unless($polyscan_model || $polyphred_model){
        $self->error_message("No child models to combine variants on!");
        die;
    }
    my $polyscan_genotype = $self->next_or_undef($polyscan_model);
    my $polyphred_genotype = $self->next_or_undef($polyphred_model);
    while ($polyphred_genotype or $polyscan_genotype){
        my ($chr1, $start1, $chr2, $start2);
        if ($polyscan_genotype){
            $chr1 = $polyscan_genotype->{chromosome};
            $start1 = $polyscan_genotype->{start};
        }
        if ($polyphred_genotype){
            $chr2 = $polyphred_genotype->{chromosome};
            $start2 = $polyphred_genotype->{start};
        }
        my $cmp = compare_position($chr1, $start1, $chr2, $start2);
        unless (defined $cmp){
            if ($polyphred_genotype and !$polyscan_genotype){
                $cmp = 1;
            }elsif( $polyscan_genotype and !$polyphred_genotype){
                $cmp = -1;
            }
        }
        if ($cmp < 0){

            my $genotype = $self->generate_genotype($polyscan_genotype, undef);
            $ofh->print($self->format_genotype_line($genotype) );
            $polyscan_genotype = $self->next_or_undef($polyscan_model);

        }elsif ($cmp > 0){

            my $genotype = $self->generate_genotype(undef, $polyphred_genotype);
            $ofh->print($self->format_genotype_line($genotype));
            $polyphred_genotype = $self->next_or_undef($polyphred_model);

        }elsif ($cmp == 0){

            my $genotype = $self->generate_genotype($polyscan_genotype, $polyphred_genotype);    
            $ofh->print($self->format_genotype_line($genotype));
            $polyphred_genotype = $self->next_or_undef($polyphred_model);
            $polyscan_genotype = $self->next_or_undef($polyscan_model);

        }else{
            $self->error_message("Could not compare polyphred and polyscan genotypes:".Dumper $polyphred_genotype.Dumper $polyscan_genotype);
            die;
        }
    }
}

sub generate_genotype{
    my ($self, $scan_g, $phred_g) = @_;
    if ($scan_g && $phred_g){
        if ( $scan_g->{genotype} eq $phred_g->{genotype} ){
            $scan_g->{polyphred_score} = $phred_g->{score};
            $scan_g->{polyphred_read_count} = $phred_g->{read_count};
            $scan_g->{polyscan_score} = $scan_g->{score};
            $scan_g->{polyscan_read_count} = $scan_g->{read_count};
            
            return $scan_g;

        }elsif ($scan_g->{score} > 75){
            return $self->generate_genotype($scan_g, undef);
        }else{
            return $self->generate_genotype(undef, $phred_g);
        }
    
    }elsif($scan_g){
        $scan_g->{polyphred_score} = 0;
        $scan_g->{polyphred_read_count} = 0;
        $scan_g->{polyscan_score} = $scan_g->{score};
        $scan_g->{polyscan_read_count} = $scan_g->{read_count};

        return $scan_g;

    }elsif($phred_g){
        $phred_g->{polyphred_score} = $phred_g->{score}; 
        $phred_g->{polyphred_read_count} = $phred_g->{read_count};
        $phred_g->{polyscan_score} = 0;
        $phred_g->{polyscan_read_count} = 0;

        return $phred_g;

    }else{
        $self->error_message("no polyscan/polyphred genotypes passed in to predict genotype");
    }
}

sub format_genotype_line{
    my ($self, $genotype) = @_;
    return join("\t", map { $genotype->{$_} } $self->columns)."\n";
}

sub columns{
    my $self = shift;
    return qw(
    chromosome 
    start 
    stop 
    hugo_symbol
    variant_type
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    genotype 
    polyscan_score 
    polyphred_score
    polyscan_read_count
    polyphred_read_count
    );
}

sub next_hq_genotype{
    my $self = shift;
    unless ($self->hq_gfh){
        my $genotype_file = $self->genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->hq_gfh($fh)
    }
    my $line = $self->hq_gfh->getline;
    unless ($line){
        $self->hq_gfh(undef);
        return undef;
    }
    my $genotype = $self->parse_line($line);
    return $genotype;
}

sub next_lq_genotype{
    my $self = shift;
    unless ($self->lq_gfh){
        my $genotype_file = $self->genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->lq_gfh($fh)
    }
    my $line = $self->lq_gfh->getline;
    unless ($line){
        $self->lq_gfh(undef);
        return undef;
    }
    my $genotype = $self->parse_line($line);
    return $genotype;
}

1;
