package Genome::Model::Sanger;

use strict;
use warnings;
use IO::File;
use File::Copy "cp";
use Data::Dumper;
use above "Genome";
use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;


class Genome::Model::Sanger{
    is => 'Genome::Model',
    has => [
        gfh => {
            is=>'IO::Handle',
            doc=>'genotype file handle',
            is_optional => 1,
        },
        process_param_set_id => { 
            via=> 'processing_profile',
            doc => 'The processing param set used', 
        },
        technology=> { 
            via=> 'processing_profile',
            doc => 'The processing param set used', 
        },
    ],
};

sub create{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    mkdir $self->model_directory;
    return $self;
}

sub type{
    my $self = shift;
    return $self->name;
}

sub model_directory{
    my $self = shift;
    return $self->base_directory."/".$self->name;
}

sub base_directory {
    my $self = shift;
    return '/gscmnt/834/info/medseq/sanger';
}

# Returns the full path to where the current genotype file is.
# This contains the consensus based upon the pcr product data
# at the polyphred or polyscan level
sub pcr_product_genotype_file {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $type = $self->type;
    
    my $file_location = "$model_dir/$type" . ".genotype.tsv";

    return $file_location; 
}

# Parses the line that was passed in for information and stuffs it into a hash
# Relys on the columns function to tell us the order the data is coming in on the line
sub parse_line {
    my ($self, $line) = @_;
    my $current_line;

    if (!$line) {
        return undef;
    }

    $current_line->{unparsed_line} = $line;
    chomp $line;
    my @split_line= split("\t", $line);

    # Grab all columns from the file and stuff them into the hash
    # Should appear in file in the order of @keys below
    foreach my $key ($self->columns){
        my $val = shift @split_line;
        $current_line->{$key} = $val if $val;
    }

    return $current_line;
}

#Takes in a hash of pcr_product_genotypes and inserts these into the pcr_product_genotype file
sub add_pcr_product_genotypes{
    my ($self, @pcr_product_data) = @_;

    # Sort the data for easier insertion
    @pcr_product_data =  sort { compare_position($a->{chromosome}, $a->{start}, $b->{chromosome}, $b->{start}) } sort { $a->{pcr_product_name} cmp $b->{pcr_product_name} } @pcr_product_data;
    
    my $pcr_file = $self->pcr_product_genotype_file;
    my $pcr_out = $self->pcr_product_genotype_file.".tmp";

    my $pofh = IO::File->new("> $pcr_out");
    unless ($pofh){ 
        $self->error_message("Can't open pcr product tmp outfile!");
        die;
    }
    $self->reset_gfh;

    # Grab data from both the existing file and the new incoming data
    my $file_pcr_product_genotype = $self->next_pcr_product_genotype;
    my $new_pcr_product_genotype = shift @pcr_product_data;
    
    while ( defined $file_pcr_product_genotype ){
        if  ($new_pcr_product_genotype){
            my $new_chromosome = $new_pcr_product_genotype->{chromosome};
            my $new_start = $new_pcr_product_genotype->{start};

            my $file_chromosome = $file_pcr_product_genotype->{chromosome};
            my $file_start = $file_pcr_product_genotype->{start};

            # Compare positions and insert the earliest position into the output file
            my $pos_cmp = compare_position($new_chromosome, $new_start, $file_chromosome, $file_start);
            if ($pos_cmp < 0){ #current data to add is before current position in file
                $pofh->print($self->format_pcr_product_genotype_line($new_pcr_product_genotype));
                $new_pcr_product_genotype = shift @pcr_product_data;
                next;
            }elsif ($pos_cmp > 0){ #current data position is after current position in the file
                $pofh->print($self->format_pcr_product_genotype_line($file_pcr_product_genotype));
                $file_pcr_product_genotype = $self->next_pcr_product_genotype;
                next;
            }elsif ($pos_cmp == 0){ #current data to add is at current position
                my $pcr_cmp = $new_pcr_product_genotype->{pcr_product_name} cmp $file_pcr_product_genotype->{pcr_product_name};
                if ($pcr_cmp < 0){ #new_pcr name less than current file
                    $pofh->print($self->format_pcr_product_genotype_line($new_pcr_product_genotype));
                    $new_pcr_product_genotype = shift @pcr_product_data;
                    next;
                }elsif($pcr_cmp > 0 ){  #file name less than newer
                    $pofh->print($self->format_pcr_product_genotype_line($file_pcr_product_genotype));
                    $file_pcr_product_genotype = $self->next_pcr_product_genotype;
                    next;
                }elsif($pcr_cmp == 0){  #compare for equality
                    #if the pcr products are the same... we should have the same answer here... otherwise bomb out
                    # Check for reverse orientation as well
                    if (($file_pcr_product_genotype->{allele1} eq $new_pcr_product_genotype->{allele1}) &&
                         ($file_pcr_product_genotype->{allele2} eq $new_pcr_product_genotype->{allele2})) {
                        $pofh->print($self->format_pcr_product_genotype_line($file_pcr_product_genotype));
                        $file_pcr_product_genotype = $self->next_pcr_product_genotype;
                        $new_pcr_product_genotype = shift @pcr_product_data;
                        next;
                    } else {
                        $self->error_message("New data and old data for the same pcr product and position disagree on alleles. New data: ". 
                            Dumper $new_pcr_product_genotype . "Old data: " . Dumper $file_pcr_product_genotype);
                        die;
                    }
                } else {
                    $self->error_message("Couldn't get a pcr product comparison for pcr products (" . 
                        $new_pcr_product_genotype->{pcr_product_name} . ", " .
                        $file_pcr_product_genotype->{pcr_product_name} . ").");
                    die;
                }
            }else{
                $self->error_message("Couldn't get a position comparison for coords( $new_chromosome, $new_start, $file_chromosome, $file_start )");
                die;
            }
        }
        else {
            $pofh->print($self->format_pcr_product_genotype_line($file_pcr_product_genotype));
            $file_pcr_product_genotype = $self->next_pcr_product_genotype;
        }
    }

    # Old data is exhausted... add any remaining new data
    if ($new_pcr_product_genotype){
        $pofh->print($self->format_pcr_product_genotype_line($new_pcr_product_genotype));
    }
    for $new_pcr_product_genotype (@pcr_product_data) {
        $pofh->print($self->format_pcr_product_genotype_line($new_pcr_product_genotype));
    }
    
    $pofh->close;
    $self->reset_gfh;

    # TODO : figure this out.
    cp $pcr_out, $pcr_file;
    return 1;
}

# Formats a line from a hash to be printed
sub format_pcr_product_genotype_line{
    my ($self, $genotype) = @_;
    my $line = $genotype->{unparsed_line};
    return $line if $line;
    my $timestamp = time; 
    $genotype->{timestamp} ||= $timestamp;
    return join("\t", map { $genotype->{$_} } $self->columns)."\n";
}

# Takes in an array of pcr product genotypes and finds the simple majority vote for a genotype
# For that sample and position among all pcr products
sub predict_genotype{
    my ($self, @genotypes) = @_;

    # Check for input
    unless (@genotypes){
        $self->error_message("No pcr product genotypes passed in");
        die;
    }
    # If there is only one input, it is the answer
    if (@genotypes == 1){
        return shift @genotypes;
    # Otherwise take a majority vote for genotype among the input
    }else{
        my %genotype_hash;
        foreach my $genotype (@genotypes){
            push @{$genotype_hash{$genotype->{allele1}.$genotype->{allele2} } }, $genotype;
        }
        my $max_vote=0;
        my $dupe_vote=0;
        my $genotype_call;
        foreach my $key (keys %genotype_hash){
            if ($max_vote <= scalar @{$genotype_hash{$key} }){
                $dupe_vote = $max_vote;
                $max_vote = scalar @{$genotype_hash{$key}};
                $genotype_call = $key;
            }
        }
        # If there is no majority vote, the genotype is X X
        if ($max_vote == $dupe_vote){
            my $return_genotype = shift @genotypes;  
            $return_genotype->{allele1} = 'X';
            $return_genotype->{allele2} = 'X';
            foreach my $val( qw/variant_type allele1_type allele2_type score read_count/){
                $return_genotype->{$val} = '-';
            }
            return $return_genotype;
        # Otherwise, return the majority vote     
        }else{
            my $read_count=0;
            foreach my $genotype (@{$genotype_hash{$genotype_call}}){
                $read_count += $genotype->{read_count};
            }
            my $return_genotype = shift @{$genotype_hash{$genotype_call}};
            $return_genotype->{read_count} = $read_count;
            return $return_genotype;
        }
    }
}

# List of columns present in the sanger model files
sub columns{
    my $self=shift;
    return qw(
    chromosome 
    start 
    stop 
    sample_name
    variant_type
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    score 
    hugo_symbol
    read_count
    pcr_product_name
    timestamp
    );
}

# Closes and undefs the file handle
sub reset_gfh{
    my $self = shift;
    $self->gfh->close if $self->gfh;
    $self->gfh(undef);
}

# Returns the next line of raw data (one pcr product)
sub next_pcr_product_genotype{
    my $self = shift;
 
    # Open the file handle if we have not already
    unless ($self->gfh){
        my $pcr_product_genotype_file = $self->pcr_product_genotype_file;
        my $fh = IO::File->new("< $pcr_product_genotype_file");
        return undef unless $fh;
        $self->gfh($fh)
    }
    
    # Get and parse the line or return undef
    my $line = $self->gfh->getline;
    unless ($line){
        return undef;
    }

    my $pcr_product_genotype = $self->parse_line($line);
    return $pcr_product_genotype;
}

# Returns the genotype for the next position for a sample...
# This takes a simple majority vote from all pcr products for that sample and position
sub next_sample_genotype {
    my $self = shift;

    # Open the file handle if we have not already
    unless ($self->gfh){
        my $pcr_product_genotype_file = $self->pcr_product_genotype_file;
        my $fh = IO::File->new("< $pcr_product_genotype_file");
        return undef unless $fh;
        $self->gfh($fh)
    }

    # Get and parse the line or return undef
    my @sample_pcr_product_genotypes;
    my ($current_chromosome, $current_position, $current_sample);
    
    # Grab all of the pcr products for a position and sample
    while ( (defined (my $pos = $self->gfh->tell)) && (my $genotype = $self->next_pcr_product_genotype)){
        my $chromosome = $genotype->{chromosome};
        my $position = $genotype->{start};
        my $sample = $genotype->{sample_name};

        unless($chromosome and $position and $sample){
            $DB::single = 1;
        }

        $current_chromosome ||= $chromosome;
        $current_position ||= $position;
        $current_sample ||= $sample;


        # If we have hit a new sample or position, rewind a line and return the genotype of what we have so far
        if ($current_chromosome ne $chromosome || $current_position ne $position || $current_sample ne $sample) {
            $self->gfh->seek($pos, 0);
            my $new_genotype = $self->predict_genotype(@sample_pcr_product_genotypes);
            return $new_genotype;
        }

        push @sample_pcr_product_genotypes, $genotype;
    }

    # If the array is empty at this point, we have reached the end of the file
    if (scalar(@sample_pcr_product_genotypes) == 0) {
        return undef;
    }

    # Get and return the genotype for this position and sample
    my $new_genotype = $self->predict_genotype(@sample_pcr_product_genotypes);
    return $new_genotype;
}

1;
