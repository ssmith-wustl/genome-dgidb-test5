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
    is_abstract => 1,
    has => [
        gfh => {
            is=>'IO::Handle',
            doc=>'genotype file handle',
            is_optional => 1,
            },
        pfh => {
            is =>'IO::Handle',
            doc=>'pcr product file handle',
            is_optional => 1,
            },
        process_param_set_id => { via=> 'processing_profile' }
        ],
};

sub create{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    mkdir $self->model_directory;
    return $self;
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
sub genotype_file {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $model_name = $self->name;
    my $type = $self->type;

    # Replace spaces with underscores for a valid file name
    $model_name =~ s/ /_/g;
    
    my $file_location = "$model_dir/$type" . "_variants.genotype.tsv";

    return $file_location; 
}

# Returns the full path to where the pcr product genotype file is.
# This contains all of the data from the individual pcr products.
# This data is used to determine the genotypes for the genotype file
sub pcr_product_genotype_file {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $model_name = $self->name;
    my $type = $self->type;

    # Replace spaces with underscores for a valid file name
    $model_name =~ s/ /_/g;
    
    my $file_location = "$model_dir/$type" . "_variants.all_pcr_product_genotype.tsv";
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

#Takes in a hash of pcr_product_genotypes, inserts these into the pcr_product_genotype file, updates any genotypes in the genotype file where new data has been added
sub add_pcr_product_genotypes{
    my ($self, @pcr_product_data) = @_;

    @pcr_product_data = sort { compare_position($a->{chromosome}, $a->{start}, $b->{chromosome}, $b->{start}) } @pcr_product_data;
    
    my $pcr_file = $self->pcr_product_genotype_file;
    my $pcr_out = $self->pcr_product_genotype_file.".tmp";

    my $pofh = IO::File->new("> $pcr_out");
    my $pfh = IO::File->new("< $pcr_file");
    unless ($pofh){ 
        $self->error_message("Can't open pcr product tmp outfile!");
        die;
    }

    my @new_genotypes; #stores new cumulative genotype calls from pcr_product_genotypes
    
    while (@pcr_product_data){
        
        my $new_pcr_product_genotype = shift @pcr_product_data;
        my $new_chromosome = $new_pcr_product_genotype->{chromosome};
        my $new_start = $new_pcr_product_genotype->{start};

        my @new_data_for_position;
        push @new_data_for_position, $new_pcr_product_genotype;

        while (@pcr_product_data and compare_position($new_chromosome, $new_start, $pcr_product_data[0]->{chromosome}, $pcr_product_data[0]->{start}) == 0){
            my $same_position = shift @pcr_product_data;
            push @new_data_for_position, $same_position;
        } #grap all new

        my @previous_pcr_product_genotypes; #stores previous genotypes from pcr_product_genotype_file

        my $printed;
        if ($pfh){
            while (defined (my $pos = $pfh->tell) and my $line = $pfh->getline){
                my ($chromosome, $start) = split("\t", $line);

                my $cmp = compare_position($new_chromosome, $new_start, $chromosome, $start);
                if ($cmp > 0){ #current data to add is ahead of current position in file
                    $pofh->print($line);
                }elsif ($cmp == 0){ #current data to add is at current position
                    push @previous_pcr_product_genotypes, $self->parse_line($line);
                }else{ #current data position is less than the current position in the file
                    #process @previous_pcr_product_genotypes
                    my @uniq = $self->uniq_pcr_product_genotypes(@previous_pcr_product_genotypes, @new_data_for_position); #pass in previous first to preserve earlier timestamp

                    foreach my $pcr_product_genotype (@uniq){
                        $pofh->print($self->format_pcr_product_genotype_line($pcr_product_genotype));
                    }
                    $printed = 1;
                    my $new_genotype = $self->predict_genotype(@uniq);
                    push @new_genotypes, $new_genotype;
                    $pfh->seek($pos, 0);
                    last;
                }
            }
        }
        unless ($printed){
            my @uniq = $self->uniq_pcr_product_genotypes(@new_data_for_position); #pass in previous first to preserve earlier timestamp
            foreach my $pcr_product_genotype (@uniq){
                $pofh->print($self->format_pcr_product_genotype_line($pcr_product_genotype));
            }
            my $new_genotype = $self->predict_genotype(@uniq);
            push @new_genotypes, $new_genotype;
        }
    }

    #update cumulative genotypes
    my $genotype_file = $self->genotype_file;
    my $genotype_out = $self->genotype_file.".tmp";

    my $gofh = IO::File->new("> $genotype_out");
    my $gfh = IO::File->new("< $genotype_file");
    unless ($gofh){ 
        $self->error_message("Can't open genotype tmp outfile!");
        die;
    }

    while (@new_genotypes){  #TODO, finish up
        
        my $new_genotype = shift @new_genotypes;
        my $new_chromosome = $new_genotype->{chromosome};
        my $new_start = $new_genotype->{start};

        while (@new_genotypes and compare_position($new_chromosome, $new_start, $new_genotypes[0]->{chromosome}, $new_genotypes[0]->{start}) == 0){
            $self->error_message("Multiple genotype predictions for same position! ",Dumper $new_genotype,Dumper @new_genotypes);
            die;
        } #grab all new

        my $printed_replacement;
        if ($gfh){
            while (defined (my $pos = $gfh->tell) and my $line = $gfh->getline){
                my ($chromosome, $start) = split("\t", $line);

                my $cmp = compare_position($new_chromosome, $new_start, $chromosome,$start);
                if ($cmp > 0){ #current data to add is ahead of current position in file
                    $gofh->print($line);
                }elsif ($cmp == 0){ #current data to add is at current position
                    $gofh->print( $self->format_genotype_line($new_genotype) );
                    $printed_replacement = 1;
                }else{ #current data position is less than the current position in the file
                    #process @previous_pcr_product_genotypes
                    $gofh->print($self->format_genotype_line($new_genotype) ) unless $printed_replacement;
                    $printed_replacement = 1;
                    $gfh->seek($pos, 0);
                    last;
                }
            }
        }
        unless ($printed_replacement){
            $gofh->print($self->format_genotype_line($new_genotype) )
        }
    }

    close $gofh;
    close $gfh if $gfh;
    close $pofh;
    close $pfh if $pfh;

    cp $pcr_out, $pcr_file;
    cp $genotype_out, $genotype_file;
    return 1;
}

sub uniq_pcr_product_genotypes{
    my ($self, @genotypes) = @_;
    my %pcr_keys;
    foreach my $genotype (@genotypes){
        my $key =$genotype->{pcr_product_name};
        $pcr_keys{ $key } = $genotype unless $pcr_keys{$key};
    }
    return map { $pcr_keys{$_} } keys %pcr_keys;
}

sub format_pcr_product_genotype_line{
    my ($self, $genotype) = @_;
    my $line = $genotype->{unparsed_line};
    return $line if $line;
    my $timestamp = time; 
    $genotype->{timestamp} ||= $timestamp;
    return join("\t", map { $genotype->{$_} } $self->columns)."\n";
}

sub format_genotype_line{
    my ($self, $genotype) = @_;
    return join("\t", map { $genotype->{$_} } grep { $_ !~ /pcr_product_name|timestamp/} $self->columns)."\n";
}

sub predict_genotype{
    my ($self, @genotypes) = @_;
    unless (@genotypes){
        $self->error_message("No pcr product genotypes passed in");
        die;
    }
    if (@genotypes == 1){
        return shift @genotypes;
    }else{
        my %genotype_hash;
        foreach my $genotype (@genotypes){
            push @{$genotype_hash{$genotype->{genotype}}}, $genotype;
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
        if ($max_vote == $dupe_vote){
            my $return_genotype = shift @genotypes;  
            $return_genotype->{genotype} = 'XX';
            foreach my $val( qw/variant_type allele1 allele1_type allele2 allele2_type score read_count/){
                $return_genotype->{$val} = '-';
            }
            return $return_genotype;
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

sub columns{
    my $self=shift;
    return qw(
    chromosome 
    start 
    stop 
    variant_type
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    genotype 
    score 
    hugo_symbol
    read_count
    pcr_product_name
    timestamp
    );
}

sub next_genotype{
    my $self = shift;
    unless ($self->gfh){
        my $genotype_file = $self->genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->gfh($fh)
    }
    my $line = $self->gfh->getline;
    unless ($line){
        $self->gfh(undef);
        return undef;
    }
    my $genotype = $self->parse_line($line);
    return $genotype;
}

sub next_pcr_product_genotype{
    my $self = shift;
    unless ($self->pfh){
        my $pcr_product_genotype_file = $self->pcr_product_genotype_file;
        my $fh = IO::File->new("< $pcr_product_genotype_file");
        return undef unless $fh;
        $self->pfh($fh)
    }
    my $line = $self->pfh->getline;
    unless ($line){
        $self->pfh(undef);
        return undef;
    }
    my $pcr_product_genotype = $self->parse_line($line);
    return $pcr_product_genotype;
}

1;
