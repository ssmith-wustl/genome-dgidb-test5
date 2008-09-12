package Genome::Model::Sanger;

use strict;
use warnings;
use IO::File;
use File::Copy "cp";
use File::Basename;
use Data::Dumper;
use Genome;
use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;


class Genome::Model::Sanger{
    is => 'Genome::Model',
    has => [
        processing_profile           => { is => 'Genome::ProcessingProfile::Sanger', id_by => 'processing_profile_id' },
        snps => {
            is => 'arrayref',
            doc => 'The union of all the snps from the input files for this model',
        },
        indels => {
            is => 'arrayref',
            doc => 'The union of all the indels from the input files for this model',
        },
        sensitivity => { 
            via => 'processing_profile',
            doc => 'The processing param set used', 
        },
        research_project => { 
            via=> 'processing_profile',
            doc => 'research project that this model belongs to', 
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

    unless (-d $self->model_directory) {
        $self->error_message("Failed to create model directory: " . $self->model_directory);
        return undef;
    }


    #make required non-build directories
    mkdir $self->pending_instrument_data_dir;
    unless (-d $self->pending_instrument_data_dir) {
        $self->error_message("Failed to create instrument data directory: " . $self->pending_instrument_data_dir);
        return undef;
    }
    
    mkdir $self->source_instrument_data_dir;
    unless (-d $self->source_instrument_data_dir) {
        $self->error_message("Failed to create source instrument data directory: " . $self->source_instrument_data_dir);
        return undef;
    }

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

# Returns the next line of raw data (one pcr product)
# TODO: Switch this to get the next line from MG::IO::Polyscan or phred
# Return 1 line from the variants in that file...
# But probably need to somehow glob all of the input files together into one class level array?
sub next_pcr_product_genotype{
    my $self = shift;
    
    unless (defined($self->snps) || defined ($self->indels)) {
        $self->setup_input;
    }

    # Get and parse the line or return undef
    if ($self->snps){
        my $line = shift @{$self->snps};
        return $line;
    }
    if ($self->indels){
        my $line = shift @{$self->indels};
        return $line;
    }
    return undef;
}

# Returns the genotype for the next position for a sample...
# This takes a simple majority vote from all pcr products for that sample and position
# TODO: Switch this to get the next line from MG::IO::Polyscan or phred
# But probably need to somehow glob all of the input files together into one class level array?
sub next_sample_genotype {
    my $self = shift;

    # Get and parse the line or return undef
    my @sample_pcr_product_genotypes;
    my ($current_chromosome, $current_position, $current_sample);
    
    # Grab all of the pcr products for a position and sample
    while ( my $genotype = $self->next_pcr_product_genotype){
        my $chromosome = $genotype->{chromosome};
        my $position = $genotype->{start};
        my $sample = $genotype->{sample_name};

        $current_chromosome ||= $chromosome;
        $current_position ||= $position;
        $current_sample ||= $sample;


        # If we have hit a new sample or position, rewind a line and return the genotype of what we have so far
        if ($current_chromosome ne $chromosome || $current_position ne $position || $current_sample ne $sample) {
            unshift @{$self->snps}, $genotype;
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

# Returns the latest complete build number
sub current_version{
    my $self = shift;
    my $archive_dir = $self->model_directory;
    my @build_dirs = `ls $archive_dir`;

    # If there are no previously existing archives
    my $version = 0;
    for my $dir (@build_dirs){
        $version++ if $dir =~/build_\d+/;
    }
    return $version;

    @build_dirs = sort {$a <=> $b} @build_dirs;
    my $last_archived = pop @build_dirs;
    my ($current_version) = $last_archived =~ m/build_(\d+)/;
    return $current_version;
}

# Returns the next available build number
sub next_version {
    my $self = shift;
    
    my $current_version = $self->current_version;
    return $current_version + 1;
}

# Returns the full path to the current build dir
sub current_build_dir {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $current_version = $self->current_version;
    my $current_build_dir = "$model_dir/build_$current_version/";

    unless (-e $current_build_dir) {
        $self->error_message("Current build dir: $current_build_dir doesnt exist");
        return undef;
    }
    
    return $current_build_dir if -d $current_build_dir;
    $self->error_message("current_build_dir $current_build_dir does not exist.  Something has gone terribly awry!");
    die;

}

# Returns full path to the input data in the current build
sub current_instrument_data_dir {
    my $self = shift;
    my $current_build_dir = $self->current_build_dir;

    my $current_instrument_data_dir = "$current_build_dir/instrument_data/";

    return $current_instrument_data_dir;
}

# Returns an array of the files in the current input dir
sub current_instrument_data_files {
    my $self = shift;

    my $current_instrument_data_dir = $self->current_instrument_data_dir;
    my @current_instrument_data_files = `ls $current_instrument_data_dir`;
    
    foreach my $file (@current_instrument_data_files){  #gets rid of the newline from ls, remove this if we switch to IO::Dir
        $file = $current_instrument_data_dir . $file;
        chomp $file;
    }

    return @current_instrument_data_files;
}

# Returns the full path to the pending input dir
sub pending_instrument_data_dir {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $pending_instrument_data_dir = "$model_dir/instrument_data/";

    return $pending_instrument_data_dir;
}

# Returns an array of the files in the pending input dir
sub pending_instrument_data_files {
    my $self = shift;

    my $pending_instrument_data_dir = $self->pending_instrument_data_dir;
    my @pending_instrument_data_files = `ls $pending_instrument_data_dir`;

    foreach my $file (@pending_instrument_data_files){  #gets rid of the newline from ls, remove this if we switch to IO::Dir
        $file = $pending_instrument_data_dir . $file;
        chomp $file;
    }

    return @pending_instrument_data_files;
}

# Returns the full path to the next build dir that should be created
sub next_build_dir {
    my $self = shift;

    my $model_dir = $self->model_directory;
    my $next_version = $self->next_version;
    my $next_build_dir = "$model_dir/build_$next_version/";

    # This should not exist yet
    if (-e $next_build_dir) {
        $self->error_message("next build dir: $next_build_dir already exists (and shouldnt)");
        return undef;
    }
    
    return $next_build_dir;
}

sub source_instrument_data_dir {
    my $self = shift;
    my $model_dir = $self->model_directory;
    my $dir_name = 'source_instrument_data';
    my $dir = "$model_dir/$dir_name";
    return $dir;
}

# Creates the new build directory,
# Copies all of the pending input files into the new build directory
sub build {
    my $self = shift;

    # Make the new build dir
    my $next_build_dir = $self->next_build_dir;
    mkdir $next_build_dir;

    unless (-e $next_build_dir) {
        $self->error_message("Failed to create next build dir: $next_build_dir ");
        return undef;
    }

    # Copy the pending input files to the new build dir
    my @pending_instrument_data_files = $self->pending_instrument_data_files;
    my $source_dir = $self->pending_instrument_data_dir;
    my $destination_dir = $self->current_instrument_data_dir;
    mkdir $destination_dir unless -d $destination_dir;
    for my $file (@pending_instrument_data_files) {
        cp($file, $destination_dir);

        my $destination_file = $destination_dir . basename($file);
        unless (-e $destination_file) {
            $self->error_message("Failed to copy $file to $destination_file");
            return undef;
        }
    }
    
    return 1;
}

# Grabs all of the input files from the current build, creates MG::IO modules for
# each one, grabs all of their snps and indels, and stuffs them into class variables
sub setup_input {
    my $self = shift;

    $DB::single = 1;

    my @input_files = $self->current_instrument_data_files;

    # Determine the type of parser to create
    my $type;
    if ($self->technology eq 'polyphred') {
        $type = 'Polyphred';
    } elsif ($self->technology eq 'polyscan') {
        $type = 'Polyscan';
    } else {
        $type = $self->type;
        $self->error_message("Type: $type not recognized.");
        return undef;
    }

    # Create parsers for each file, append to running lists
    # TODO eliminate duplicates!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    my (@all_snps, @all_indels);
    for my $file (@input_files) {
        my ($assembly_project_name) = $file =~ /\/([^\.\/]+)\.poly(scan|phred)\.(low|high)$/;  #TODO make sure assembly project names are going to be kosher
        my $param = lc($type);
        my $module = "MG::IO::$type";
        my $parser = $module->new($param => $file,
                                  assembly_project_name => $assembly_project_name
                              );
        my ($snps, $indels) = $parser->collate_sample_group_mutations;
        push @all_snps, @$snps if $snps;
        push @all_indels, @$indels if $indels;
    }

    # Sort by chromosome, position, and pcr product
    @all_snps =  sort { compare_position($a->{chromosome}, $a->{start}, $b->{chromosome}, $b->{start}) } sort { $a->{pcr_product_name} cmp $b->{pcr_product_name} } @all_snps;
    @all_indels =  sort { compare_position($a->{chromosome}, $a->{start}, $b->{chromosome}, $b->{start}) } sort { $a->{pcr_product_name} cmp $b->{pcr_product_name} } @all_indels;
 
    # Set the class level variables
    $self->snps(\@all_snps);
    $self->indels(\@all_indels);

    return @all_snps, @all_indels;
}

# attempts to get an existing model with the params supplied
sub get_or_create{
    my ($self, %p) = @_;
    my $research_project_name = $p{research_project};
    my $technology_type = $p{technology_type};
    my $sensitivity = $p{sensitivity};
    
    unless (defined($research_project_name) && defined($technology_type) && defined($sensitivity)) {
        $self->error_message("Insufficient params supplied to get_or_create");
        return undef;
    }

    my $model = Genome::Model::Sanger->get(
        name => $research_project_name.$technology_type.$sensitivity);
    #research_project => $research_project_name,
    #technology => $technology_type,
    #sensitivity => $sensitivity,
    );

    unless ($model){
        my $pp = Genome::ProcessingProfile::Sanger->get(
            name => "$research_project_name.$technology_type.$sensitivity",
            #research_project => $research_project_name,
            #technology => $technology_type,
            #sensitivity => $sensitivity,
        );
        unless ($pp){
            $pp = Genome::ProcessingProfile::Sanger->create(
                name => "$research_project_name.$technology_type.$sensitivity",
                research_project => $research_project_name,
                technology => $technology_type,
                sensitivity => $sensitivity,
            );
        }
        $model = Genome::Model::Sanger->create(
            subject_name => $research_project_name,
            sample_name => $research_project_name,
            processing_profile => $pp,
            name => $pp->name,
        );
    }
    return $model;
}

1;
