package Genome::Model::CombineVariants::AnnotateVariants;
#:adukes short term, nothing. long term - use the annotator genome tool after evalutating the rest of the CombineVariants env

use strict;
use warnings;

use IO::File;
use Genome;
use Data::Dumper;

class Genome::Model::CombineVariants::AnnotateVariants{
    is => ['Command'],
    has => [
    ],
    has_optional => [
        input_file => {
            is => 'IO::File',
            doc => 'The input file handle'
        },
        input_file_name => {
            is => 'String',
            doc => 'The name of the input file.'
        },
        output_file_name => {
            is => 'String',
            doc => 'The name of the output file.'
        },
    ],
    has_input => [
        chromosome => {
           is  => 'String', 
           doc => 'chromosome to annotate',
       },
       quality => {
           is => 'String',
           doc => 'hq or lq',
       },
       directory => {
           is => 'String',
           doc => 'latest build directory',
       },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    return $self;
}

# Runs annotation for both the high and low sensitivity genotype files using the VariantAnnotator.pm
sub execute {
    my ($self) = @_;

    my $dir = $self->directory;
    my $chromosome = $self->chromosome;
    my $quality = $self->quality;

    my $input_file = "$dir/$quality" . "_genotype_$chromosome.tsv";
    my $output_file = "$dir/$quality" . "_annotated_genotype_$chromosome.tsv";
    $self->input_file_name($input_file);
    $self->output_file_name($output_file);

    my $annotator;
    my $db_chrom;
    my $post_annotation_file = $self->output_file_name;
    my $ofh = IO::File->new("> $post_annotation_file");
    unless ($ofh){
        $self->error_message("couldn't get output file handle for $post_annotation_file");
        die;
    }

    my $current_chromosome=0;
    while (my $genotype = $self->next_genotype){
        
        #NEW ANNOTATOR IF WE'RE ON A NEW CHROMOSOME
        if ( $current_chromosome ne $genotype->{chromosome} ){
            $current_chromosome = $genotype->{chromosome};
            my $window = $self->_get_window($current_chromosome);
            $annotator = $self->_get_annotator($window);
        }
        
        $self->print_prioritized_annotation($genotype, $annotator, $ofh);
    }

    $ofh->close;

    return 1;
}

# Gets and prints the lowest priority annotation for a given genotype
# Takes a genotype hashref from next_hq/lq_genotype
# Also takes in the current annotator object FIXME: Make this a class level var?
# Also takes in the output file handle to print to
sub print_prioritized_annotation {
    my $self = shift;
    my $genotype = shift;
    my $annotator = shift;
    my $fh = shift;
    
    # Decide which of the two alleles (or both) vary from the reference and annotate the ones that do
    for my $variant ($genotype->{allele1}, $genotype->{allele2}) {
        next if $variant eq $genotype->{reference};
        
        my @annotations;

        my $reference = $genotype->{reference};
        
        @annotations = $annotator->prioritized_transcripts(
            start => $genotype->{begin_position},
            reference => $reference,
            variant => $variant,
            chromosome_name => $genotype->{chromosome},
            stop => $genotype->{end_position},
            type => $genotype->{variation_type},
        );

        # Print the annotation with the best (lowest) priority
        my $lowest_priority_annotation;
        for my $annotation (@annotations){
            unless(defined($lowest_priority_annotation)) {
                $lowest_priority_annotation = $annotation;
            }
            if ($annotation->{priority} < $lowest_priority_annotation->{priority}) {
                $lowest_priority_annotation = $annotation;
            }
        }
        $lowest_priority_annotation->{variations} = join (",",keys %{$lowest_priority_annotation->{variations}});
        my %combo = (%$genotype, %$lowest_priority_annotation);

        $fh->print($self->format_annotated_genotype_line(\%combo));

        # Dont do this again if both alleles are the same
        last if $genotype->{allele1} eq $genotype->{allele2};
    }

    return 1;
}

# Returns a printable line for the genotype hash passed in
sub format_annotated_genotype_line{
    my ($self, $genotype) = @_;

    return join("\t", map { 
            if ( defined $genotype->{$_} ){
                $genotype->{$_} 
            }else{
                'no_value'
            } 
        } $self->annotated_columns)."\n";
}

sub annotated_columns{
    return Genome::Model::CombineVariants->annotated_columns;
}

sub genotype_columns{
    return Genome::Model::CombineVariants->genotype_columns;
}

# Format a line into a hash
# FIXME Must be kept in sync with combinevariants->parse_genotype_line... bad programming yay
sub parse_genotype_line {
    my ($self, $line) = @_;

    my @columns = split("\t", $line);
    my @headers = $self->genotype_columns;

    my $hash;
    for my $header (@headers) {
        $hash->{$header} = shift(@columns);
    }

    return $hash;
}

# Reads from the current genotype file and returns the next line as a hash
sub next_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
    unless ($self->input_file){
        my $genotype_file = $self->input_file_name;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->input_file($fh);
    }

    my $line = $self->input_file->getline;
    unless ($line){
        $self->input_file(undef);
        return undef;
    }
    chomp $line;
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

# Reads from the current pre annotation genotype file and returns the next line as a hash
# Optionally takes a chromosome and position range and returns only genotypes in that range

sub _get_window{
    my $self = shift;
    my $chromosome = shift;
    
    ############
    #TODO don't hardcode this, maybe override create iterator in Genome::Transcript
    #this build id is for the v0 build of ImportedAnnotation
    my $build_id = 96047134;
    my $build = Genome::Model::Build->get($build_id);
    #TODO remove when fixed
    ############
    
    my $iter = $build->transcript_iterator(chrom_name => $chromosome);
    my $window =  Genome::Utility::Window::Transcript->create ( iterator => $iter, range => 50000);
    return $window;
}


sub _get_annotator {
    my $self = shift;
    my ($transcript_window) = @_;

    my $annotator = Genome::Transcript::VariantAnnotator->create(
        transcript_window => $transcript_window,
        version => 'combined_v0', #TODO, update this when the hardcoded value is changed
    );
    die unless $annotator;

    return $annotator;
}

1;
