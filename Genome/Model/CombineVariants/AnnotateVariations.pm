package Genome::Model::CombineVariants::AnnotateVariations;

use strict;
use warnings;

use IO::File;
use Genome;
use Data::Dumper;
use Genome::Utility::VariantAnnotator;
use Genome::DB::Schema;
use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;

class Genome::Model::CombineVariants::AnnotateVariations {
    is => ['Command'],
    has => [
    ],
    has_optional => [
        input_file => {
            is => 'IO::File',
            doc => 'The input file handle'
        }
    ],
    has_input => [
        input_file_name => {
            is => 'String',
            doc => 'The name of the input file.'
        },
        output_file_name => {
            is => 'String',
            doc => 'The name of the output file.'
        },
    ],
    has_output => [
        output_file => { 
            is => 'String', 
            is_optional => 1, 
            doc => 'tab delimited output representing the annotated file' 
        }
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

    my $schema = Genome::DB::Schema->connect_to_dwrac;
 
    $self->error_message("Can't connect to dwrac")
        and return unless $schema;
    
    $self->output_file($self->output_file_name);

    my $annotator;
    my $db_chrom;
    my $post_annotation_file = $self->output_file;
    my $ofh = IO::File->new("> $post_annotation_file");
    unless ($ofh){
        $self->error_message("couldn't get output file handle for $post_annotation_file");
        die;
    }

    my $current_chromosome=0;
    while (my $genotype = $self->next_genotype){
        
        #NEW ANNOTATOR IF WE'RE ON A NEW CHROMOSOME
        if ( compare_chromosome($current_chromosome,$genotype->{chromosome}) != 0 ){
            $current_chromosome = $genotype->{chromosome};
            $db_chrom = $schema->resultset('Chromosome')->find(
                {chromosome_name => $genotype->{chromosome} },
            );

            unless ($db_chrom){
               $self->error_message("couldn't get db chrom from database");
               die;
            }
            $annotator = Genome::Utility::VariantAnnotator->new(
                transcript_window => $db_chrom->transcript_window(range => 50000),
            );
        }
        
        $self->print_prioritized_annotation($genotype, $annotator, $ofh);
    }

    $ofh->close;

    return 1;
}

sub reverse_complement{
    my $self = shift;
    my $string = shift;
    $string = reverse $string;
    $string =~ tr/[ATGC]/[TACG]/;
    return $string;
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
sub next_genotype_in_range{
    my $self = shift;
    return $self->next_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{start}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{start}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

1;
