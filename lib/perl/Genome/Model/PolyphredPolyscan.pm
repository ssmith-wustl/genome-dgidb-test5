package Genome::Model::PolyphredPolyscan;
#:adukes short-term remove parent bridges and models, long-term this was part of a messy project, reevaluate what is being accomplished here and decide if we still want to support it.

use strict;
use warnings;
use IO::File;
use File::Copy "cp";
use File::Spec;
use File::Temp;
use File::Basename;
use Data::Dumper;
use Genome;
use Benchmark;


class Genome::Model::PolyphredPolyscan {
    is => 'Genome::Model',
    has => [
        processing_profile => {
            is => 'Genome::ProcessingProfile::PolyphredPolyscan',
            id_by => 'processing_profile_id'
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
    has_optional => [
        combined_input_fh => {
            is  =>'IO::Handle',
            doc =>'file handle to the combined input file',
        },
        current_pcr_product_genotype => {
            is => 'Hash',
            doc => 'The current pcr product genotype... used for "peek" like functionality',
        },
    ],
    # Accessors to grab the parent CombineVariants models
    has_many_optional => [
        parent_bridges => { is => 'Genome::Model::CompositeMember', reverse_id_by => 'genome_model_member'},
        parent_models => { is => 'Genome::Model', via => 'parent_bridges', to => 'genome_model_composite'},
    ]
};

sub sequencing_platform{
    my $self = shift;
    return "sanger";
}

sub create{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
 
    my $data_dir = $self->data_directory;

    # If the data directory was not supplied, resolve what it should be by default
    unless ($data_dir) {
        $data_dir= $self->resolve_data_directory;
        $self->data_directory($data_dir);
    }
    
    # Replace spaces with underscores
    $data_dir =~ s/ /_/g;
    $self->data_directory($data_dir);

    # Make the model directory
    if (-d $data_dir) {
        $self->error_message("Data directory: " . $data_dir . " already exists before creation");
        return undef;
    }
    
    mkdir $data_dir;

    unless (-d $data_dir) {
        $self->error_message("Failed to create data directory: " . $data_dir);
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

sub build_subclass_name {
    return 'polyphred polyscan';
}

sub type{
    my $self = shift;
    return $self->name;
}

# Returns the default location where this model should live on the file system
sub resolve_data_directory {
    my $self = shift;

    my $base_directory = "/gscmnt/834/info/medseq/polyphred_polyscan/";
    my $name = $self->name;
    my $data_dir = "$base_directory/$name/";
    
    # Remove spaces so the directory isnt a pain
    $data_dir=~ s/ /_/;

    return $data_dir;
}

sub combined_input_file {
    my $self = shift;

    my $latest_build_directory = $self->latest_build_directory;
    my $combined_input_file_name = "$latest_build_directory/combined_input.tsv";

    return $combined_input_file_name;
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
            foreach my $val( qw/variant_type allele1_type allele2_type/){
                $return_genotype->{$val} = 'SNP';
            }
            foreach my $val( qw/ score /){
                $return_genotype->{$val} = '0';
            }
            return $return_genotype;
        # Otherwise, return the majority vote     
        }else{
            my $read_count=0;
            foreach my $genotype (@{$genotype_hash{$genotype_call}}){
                #$read_count += $genotype->{read_count};  #TODO incorporate allele 1 & 2 pcr and read counts, but these should be fully calculated in collate now, so probably don't need to do any extra arithmetic here
            }
            my $return_genotype = shift @{$genotype_hash{$genotype_call}};
            #$return_genotype->{read_count} = $read_count;
            return $return_genotype;
        }
    }
}

# Returns the next line of raw data (one pcr product)
sub next_pcr_product_genotype{
    my $self = shift;
 
    unless ($self->combined_input_fh) {
        $self->setup_input;
    }

    my $fh = $self->combined_input_fh;

    unless ($fh) {
        $self->error_message("Combined input file handle not defined after setup_input");
        die;
    }

    my $line = $fh->getline;
    return undef unless $line;
    chomp $line;
    my @values = split("\t", $line);

    my $genotype;
    for my $column ($self->combined_input_columns) {
        $genotype->{$column} = shift @values;
    }

    return $genotype;
}

# Returns the genotype for the next position for a sample...
# This takes a simple majority vote from all pcr products for that sample and position
sub next_sample_genotype {
    my $self = shift;

    my @sample_pcr_product_genotypes;
    my ($current_chromosome, $current_position, $current_sample);
    
    # If we have a genotype saved from last time... grab it to begin the new sample pcr product group
    if ($self->current_pcr_product_genotype) {
        my $genotype = $self->current_pcr_product_genotype;
        $current_chromosome = $genotype->{chromosome};
        $current_position = $genotype->{begin_position};
        $current_sample = $genotype->{sample_name};
        push @sample_pcr_product_genotypes, $genotype;
        $self->current_pcr_product_genotype(undef);
    }
    
    # Grab all of the pcr products for a position and sample
    while ( my $genotype = $self->next_pcr_product_genotype){
        my $chromosome = $genotype->{chromosome};
        my $position = $genotype->{begin_position};
        my $sample = $genotype->{sample_name};

        $current_chromosome ||= $chromosome;
        $current_position ||= $position;
        $current_sample ||= $sample;

        # If we have hit a new sample or position, rewind a line and return the genotype of what we have so far
        if ($current_chromosome ne $chromosome || $current_position ne $position || $current_sample ne $sample) {
            my $new_genotype = $self->predict_genotype(@sample_pcr_product_genotypes);
            $self->current_pcr_product_genotype($genotype);
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

# Returns the full path to the pending input dir
sub pending_instrument_data_dir {
    my $self = shift;

    my $data_dir = $self->data_directory;
    my $pending_instrument_data_dir = "$data_dir/instrument_data/";

    # Remove spaces, replace with underscores
    $pending_instrument_data_dir =~ s/ /_/;

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

sub source_instrument_data_dir {
    my $self = shift;
    my $data_dir = $self->data_directory;
    my $dir_name = 'source_instrument_data';
    my $dir = "$data_dir/$dir_name";
    
    # Remove spaces, replace with underscores
    $dir =~ s/ /_/;

    return $dir;
}

# List of columns present in the combined input file
sub combined_input_columns {
    my $self = shift;
    return qw(
        chromosome 
        begin_position
        end_position
        gene
        sample_name
        pcr_product_name
        variation_type
        reference
        allele1 
        allele1_type 
        allele1_read_support
        allele1_pcr_product_support
        allele2 
        allele2_type 
        allele2_read_support
        allele2_pcr_product_support
        score
        read_type
        con_pos
        filename
    );
}

# Grabs all of the input files from the current build, creates MG::IO modules for
# each one, grabs all of their snps and indels, and stuffs them into class variables
sub setup_input {
    my $self = shift;
    my $start = new Benchmark;

    my $last_complete_build = $self->last_complete_build;
    unless ($last_complete_build){
        $self->error_message("Couldn't find last complete build");
        die;
    }
    my @input_files = $last_complete_build->instrument_data_files;

    # Determine the type of parser to create
    my $type;
    if ($self->technology =~ /polyphred/i) {
        $type = 'Polyphred';
    } elsif ($self->technology =~ /polyscan/i) {
        $type = 'Polyscan';
    } else {
        $type = $self->type;
        $self->error_message("Type: $type not recognized.");
        die;
    }
    
    # Combined input file to be created from the collates of all input files
    my $combined_input_file = $self->combined_input_file;

    my $fh;
    if (-s $combined_input_file) {
        $self->status_message("Combined input file already present, skipping setup_input");
        $fh = IO::File->new("$combined_input_file");
        $self->combined_input_fh($fh);
        return 1;
    } else {
        $fh = IO::File->new(">$combined_input_file");
    }
    

    if (1) { # workflow switch
        
        require Workflow::Simple;

        ## keep the ur stuff in this process, speed optimization
        
        my $op = Workflow::Operation->create(
            name => 'collate sample group mutations',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations')
        );
        
        $op->parallel_by('input_file');

        my $input_dir = File::Temp::tempdir('input_dir_XXXXXXXX', DIR => '/gscmnt/sata835/info/medseq/temporary_data', CLEANUP => 1);

        my @copied_files = ();
        foreach my $file (@input_files) {
            my ($v,$dir,$filename) = File::Spec->splitpath($file);
            my $newname = File::Spec->catpath('',$input_dir,$filename);

            File::Copy::copy($file,$newname);

            push @copied_files, $newname;
        }

        my $output = Workflow::Simple::run_workflow_lsf(
            $op,
            'parser_type' => $type,
            'input_file' => \@copied_files,
            'output_path' => '/gscmnt/sata835/info/medseq/temporary_data'
        );
    
        unless ($output) {
            $self->error_message("Collate sample group mutations failed in workflow");
            die;
        }
        
        for my $file (@{ $output->{output_file} }) {
            my $ifh = IO::File->new('<' . $file);
            while (my $line = $ifh->getline) {
                $fh->print($line);
            }
            $ifh->close;            
            unlink($file);
        }
        for my $file (@copied_files) {
            unlink($file);
        }
    
    } else {

        # Create parsers for each file, append to running lists
        # TODO eliminate duplicates!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        for my $file (@input_files) {
            my $parser_command = Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations->create(
                parser_type => $type,
                input_file => $file,
                output_path => '/tmp'
            );

            $parser_command->execute;

            unless ($parser_command->result) {
                $self->error_message("Collate sample group mutations failed on $file");
                die;
            }

            my $ifh = IO::File->new('<' . $parser_command->output_file);
            while (my $line = $ifh->getline) {
                $fh->print($line);
            }
            $ifh->close;

            unlink $parser_command->output_file;
        }

    }
    $fh->close;

    unless (-e $combined_input_file) {
        $self->error_message("Combined input file does not exist");
        die;
    }

    my $sorted_file = "$combined_input_file.temp";

    # Sort by chromosome, position, sample... TODO: derive these numbers from columns sub
    system("sort -k1,1 -k2,2n -k5,5 $combined_input_file > $sorted_file");

    unless(-e $sorted_file) {
        $self->error_message("Failed to sort combined input file: $combined_input_file into $sorted_file");
        die;
    }
    
    unlink($combined_input_file);
    if(-e $combined_input_file) {
        $self->error_message("Failed to unlink combined input file: $combined_input_file");
        die;
    }
    
    cp($sorted_file, $combined_input_file);
    unless(-e $combined_input_file) {
        $self->error_message("Failed to copy sorted file: $sorted_file back to combined input file: $combined_input_file");
        die;
    }

    unlink($sorted_file);

    # Set up the file handle to be used as input
    my $in_fh = IO::File->new("$combined_input_file");
    $self->combined_input_fh($in_fh);

    my $stop = new Benchmark;

    my $time = timestr(timediff($stop,$start));

    $self->status_message("Setup input for model ".$self->name." time: $time");

    return 1;
}

# attempts to get an existing model with the params supplied
sub get_or_create{
    my ($class , %p) = @_;
    
    my $research_project_name = $p{research_project};
    my $technology = $p{technology};
    my $sensitivity = $p{sensitivity};
    my $data_directory = $p{data_directory};
    my $subject_name = $p{subject_name};
    my $subject_type = $p{subject_type};
    my $model_name = $p{model_name};
    my $parent_model_id = $p{parent_model_id};
    $subject_type ||= 'sample_group';

    unless (defined($research_project_name) && defined($technology) && defined($sensitivity) && defined($subject_name)) {
        $class->error_message("Insufficient params supplied to get_or_create");
        return undef;
    }

    my $pp_name = "$research_project_name.$technology.$sensitivity";
    $model_name ||= "$subject_name.$pp_name";

    my $model = Genome::Model::PolyphredPolyscan->get(
        name => $model_name,
    );

    unless ($model){
        my $pp = Genome::ProcessingProfile::PolyphredPolyscan->get(
            name => $pp_name,
            #research_project => $research_project_name,
            #technology => $technology,
            #sensitivity => $sensitivity,
        );
        unless ($pp){
            $pp = Genome::ProcessingProfile::PolyphredPolyscan->create(
                name => $pp_name, 
                research_project => $research_project_name,
                technology => $technology,
                sensitivity => $sensitivity,
            );
        }

        my $create_command = Genome::Model::Command::Create::Model->create(
            model_name => $model_name,
            processing_profile_name => $pp->name,
            subject_name => $subject_name,
            data_directory => $data_directory,
            subject_type => $subject_type,
        );

        $model = $create_command->execute();

        unless ($model) {
            $class->error_message("Failed to create model in get_or_create");
            die;
        }

        unless($parent_model_id) {
            $class->error_message("No parent_model_id provided for child polyphredpolyscan model");
            die;
        }
        my $combine_variants_model = Genome::Model::CombineVariants->get($parent_model_id);
        unless($combine_variants_model) {
            $class->error_message("Could not get parent combine variants model for id $parent_model_id");
            die;
        }

        $combine_variants_model->add_child_model($model);
    }


    
    return $model;
}

1;
