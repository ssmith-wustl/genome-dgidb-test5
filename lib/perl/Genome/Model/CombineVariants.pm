package Genome::Model::CombineVariants;
#:adukes short-term remove composite model references, long-term this was part of a messy project, reevaluate what is being accomplished here and decide if we still want to support it.

use strict;
use warnings;

use IO::File;
use Genome;
use Data::Dumper;
use Benchmark;

class Genome::Model::CombineVariants{
    is => 'Genome::Model',
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
        hq_agfh  => {
            is  =>'IO::Handle',
            doc =>'hq annotated genotype file handle',
            is_optional => 1,
        },
        lq_agfh  => {
            is  =>'IO::Handle',
            doc =>'lq annotated genotype file handle',
            is_optional => 1,
        },
        current_hq_genotype_files => {
            is => 'Arrayref',
            doc => 'The list of hq_genotype files yet to be processed',
            is_optional => 1,
        },
        current_lq_genotype_files => {
            is => 'Arrayref',
            doc => 'The list of lq_genotype files yet to be processed',
            is_optional => 1,
        },
        current_hq_annotated_genotype_files => {
            is => 'Arrayref',
            doc => 'The list of hq_annotated_genotype files yet to be processed',
            is_optional => 1,
        },
        current_lq_annotated_genotype_files => {
            is => 'Arrayref',
            doc => 'The list of lq_annotated_genotype files yet to be processed',
            is_optional => 1,
        },
    ],
};

sub sequencing_platform{
    return 'sanger';
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

    # Replace spaces with underscores
    # TODO: move up or out
    my $data_dir = $self->data_directory;
    $data_dir =~ s/ /_/g;
    $self->data_directory($data_dir);

    eval { $self->_add_source_models; };
    if ($@) {
        $self->delete;
        die $@;
    }

    return $self;
}

sub _add_source_models {
    my $self = shift;

    my $pp = $self->processing_profile;

    my @child_pps = Genome::ProcessingProfile::PolyphredPolyscan->get(
        sensitivity => ['low','high'],
        technology => ['polyphred','polyscan'],

        # TODO: this is redundant with the subject, but needed for now
        # remove me from the PP and this logic
        research_project => $self->subject_name,         
    );

    unless (@child_pps == 4) {
        die "Expected 4 processing profiles to go with this model.  Found " 
            . scalar(@child_pps) . "\n"
            . Data::Dumper::Dumper(\@child_pps);
    }

    my @previously_assigned = $self->from_models;
    my %previously_assigned = map { $_->id => 1 } @previously_assigned;

    if (@previously_assigned) {
        $self->status_message("Found " . scalar(@previously_assigned) . " models already assigned!");
    }

    my @child_models;
    for my $child_pp (@child_pps) {
        my @existing_child_models = Genome::Model->get(
            subject_name => $self->subject_name,
            processing_profile => $child_pp, 
        );
        my $child_model;
        if (@existing_child_models) {
            my $names = join(", ", map { '"' . $_->name . '"' } @existing_child_models);
            $self->status_message("Found model(s) $names for " . $child_pp->name . "\n"); 
            my @assigned = grep { $previously_assigned{$_->id} } @existing_child_models;
            if (@assigned > 1) {
                die "Multiple child models already assigned for this processing profile?!";
            }
            elsif (@assigned == 1) {
                $child_model = $assigned[0];
                $self->status_message("Model " . $child_model->id . ' "' . $child_model->name . '" is already assigned to this model.'); 
            }
            elsif (@existing_child_models > 1) {
                die "Assignment of a child model is ambiguous because there are multiple matches!"; 
            }
            else {
                $child_model = $existing_child_models[0];
                $self->status_message("Assigning previously existing model " . $child_model->id . ' "' . $child_model->name . "\"\n");
                $self->add_from_model(from_model => $child_model);
            } 
        }
        else {
            $self->status_message("No underlying model found for profile: " . $child_pp->name . ".  Creating...\n");    
            $child_model = Genome::Model::PolyphredPolyscan->create(
                name => $self->subject_name . ' ' . $child_pp->name,
                subject_name => $self->subject_name,
                subject_type => $self->subject_type,
                processing_profile => $child_pp,
            );
            unless ($child_model) {
                die "Failed to create model!" . Genome::Model->error_message;
            }
            $self->add_from_model(from_model => $child_model);
        }
        push @child_models, $child_model;
    }

    return @child_models;
}
    
sub build_subclass_name {
    return 'combine_variants';
}

# Returns the next hq genotype from the conglomeration of all of the hq genotype files
sub next_hq_annotated_genotype {
    my $self = shift;

    # Set the current files if they have not been set yet
    unless (defined($self->hq_agfh)||defined($self->current_hq_annotated_genotype_files)) {
        my @hq_genotype_files = $self->hq_annotated_genotype_files;
        $self->current_hq_annotated_genotype_files(\@hq_genotype_files);
    }
 
    # Open the file handle if it hasnt been
    unless ($self->hq_agfh){
        my $genotype_file;
        
        return undef unless $self->current_hq_annotated_genotype_files;
        # Work around for UR returning a scalar if there is only one element in the array
        if (ref($self->current_hq_annotated_genotype_files)) {
            $genotype_file = shift @{$self->current_hq_annotated_genotype_files};
        } else {
            $genotype_file = $self->current_hq_annotated_genotype_files;
            $self->current_hq_annotated_genotype_files(undef);
        }
        return unless $genotype_file;
        
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        
        $self->hq_agfh($fh);
    }

    # Try to get a new line from one of the files until we are out of files
    my $line;
    while (!defined($line)) {
        # Try to get a line
        $line = $self->hq_agfh->getline;

        # If we cannot get one, try the next file
        unless ($line){
            my $genotype_file = shift @{$self->current_hq_annotated_genotype_files};
            # If we are out of files, unset the fh and return
            unless ($genotype_file) {
                $self->hq_agfh(undef);
                return undef;
            }
            
            # set the new fh
            my $fh = IO::File->new("< $genotype_file");
            unless ($fh) {
                $self->error_message("Failed to get file handle for $genotype_file");
                die;
            }

            $self->hq_agfh($fh);
        }
    }
    
    chomp $line;
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

# Returns the next lq genotype from the conglomeration of all of the lq genotype files
sub next_lq_annotated_genotype {
    my $self = shift;

    # Set the current files if they have not been set yet
    unless (defined($self->lq_agfh)||defined($self->current_lq_annotated_genotype_files)) {
        my @lq_genotype_files = $self->lq_annotated_genotype_files;
        $self->current_lq_annotated_genotype_files(\@lq_genotype_files);
    }
 
    # Open the file handle if it hasnt been
    unless ($self->lq_agfh){
        my $genotype_file;

        return undef unless $self->current_hq_genotype_files;
        # Work around for UR returning a scalar if there is only one element in the array
        if (ref($self->current_lq_annotated_genotype_files)) {
            $genotype_file = shift @{$self->current_lq_annotated_genotype_files};
        } else {
            $genotype_file = $self->current_lq_annotated_genotype_files;
            $self->current_lq_annotated_genotype_files(undef);
        }
        return unless $genotype_file;
        
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        
        $self->lq_agfh($fh);
    }

    # Try to get a new line from one of the files until we are out of files
    my $line;
    while (!defined($line)) {
        # Try to get a line
        $line = $self->lq_agfh->getline;

        # If we cannot get one, try the next file
        unless ($line){
            my $genotype_file = shift @{$self->current_lq_annotated_genotype_files};
            # If we are out of files, unset the fh and return
            unless ($genotype_file) {
                $self->lq_agfh(undef);
                return undef;
            }
            
            # set the new fh
            my $fh = IO::File->new("< $genotype_file");
            unless ($fh) {
                $self->error_message("Failed to get file handle for $genotype_file");
                die;
            }

            $self->lq_agfh($fh);
        }
    }
    
    chomp $line;
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

# Returns the next hq genotype from the conglomeration of all of the hq genotype files
sub next_hq_genotype {
    my $self = shift;

    # Set the current files if they have not been set yet
    unless (defined($self->hq_gfh)||defined($self->current_hq_genotype_files)) {
        my @hq_genotype_files = $self->hq_genotype_files;
        $self->current_hq_genotype_files(\@hq_genotype_files);
    }
 
    # Open the file handle if it hasnt been
    unless ($self->hq_gfh){
        my $genotype_file;
        
        return undef unless $self->current_hq_genotype_files;
        # Work around for UR returning a scalar if there is only one element in the array
        if (ref($self->current_hq_genotype_files)) {
            $genotype_file = shift @{$self->current_hq_genotype_files};
        } else {
            $genotype_file = $self->current_hq_genotype_files;
            $self->current_hq_genotype_files(undef);
        }
        return unless $genotype_file;
        
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        
        $self->hq_gfh($fh);
    }

    # Try to get a new line from one of the files until we are out of files
    my $line;
    while (!defined($line)) {
        # Try to get a line
        $line = $self->hq_gfh->getline;

        # If we cannot get one, try the next file
        unless ($line){
            my $genotype_file = shift @{$self->current_hq_genotype_files};
            # If we are out of files, unset the fh and return
            unless ($genotype_file) {
                $self->hq_gfh(undef);
                return undef;
            }
            
            # set the new fh
            my $fh = IO::File->new("< $genotype_file");
            unless ($fh) {
                $self->error_message("Failed to get file handle for $genotype_file");
                die;
            }

            $self->hq_gfh($fh);
        }
    }
    
    chomp $line;
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

# Returns the next lq genotype from the conglomeration of all of the lq genotype files
sub next_lq_genotype {
    my $self = shift;

    # Set the current files if they have not been set yet
    unless (defined($self->lq_gfh)||defined($self->current_lq_genotype_files)) {
        my @lq_genotype_files = $self->lq_genotype_files;
        $self->current_lq_genotype_files(\@lq_genotype_files);
    }
 
    # Open the file handle if it hasnt been
    unless ($self->lq_gfh){
        my $genotype_file;

        return undef unless $self->current_hq_genotype_files;
        # Work around for UR returning a scalar if there is only one element in the array
        if (ref($self->current_lq_genotype_files)) {
            $genotype_file = shift @{$self->current_lq_genotype_files};
        } else {
            $genotype_file = $self->current_lq_genotype_files;
            $self->current_lq_genotype_files(undef);
        }
        return unless $genotype_file;
        
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        
        $self->lq_gfh($fh);
    }

    # Try to get a new line from one of the files until we are out of files
    my $line;
    while (!defined($line)) {
        # Try to get a line
        $line = $self->lq_gfh->getline;

        # If we cannot get one, try the next file
        unless ($line){
            my $genotype_file = shift @{$self->current_lq_genotype_files};
            # If we are out of files, unset the fh and return
            unless ($genotype_file) {
                $self->lq_gfh(undef);
                return undef;
            }
            
            # set the new fh
            my $fh = IO::File->new("< $genotype_file");
            unless ($fh) {
                $self->error_message("Failed to get file handle for $genotype_file");
                die;
            }

            $self->lq_gfh($fh);
        }
    }
    
    chomp $line;
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

# Returns a list of all genotype files, hq and lq, that currently exist
sub genotype_files {
    my $self = shift;

    my @hq_files = $self->hq_genotype_files;
    my @lq_files = $self->lq_genotype_files;

    return (@hq_files, @lq_files);
}

# Returns a list of hq_genotype files that currently exist
sub hq_genotype_files {
    my $self = shift;

    my @existing_files;
    for my $chromosome (1..22, 'X', 'Y') {
        my $file = $self->hq_genotype_file_for_chromosome($chromosome);
        if (-s $file) {
            push @existing_files, $file;
        }
    }

    return @existing_files;
}

# Returns a list of lq_genotype files that currently exist
sub lq_genotype_files {
    my $self = shift;

    my @existing_files;
    for my $chromosome (1..22, 'X', 'Y') {
        my $file = $self->lq_genotype_file_for_chromosome($chromosome);
        if (-s $file) {
            push @existing_files, $file;
        }
    }

    return @existing_files;
}

# Returns a list of all annotated genotype files, hq and lq, that currently exist
sub annotated_genotype_files {
    my $self = shift;

    my @hq_files = $self->hq_annotated_genotype_files;
    my @lq_files = $self->lq_annotated_genotype_files;

    return (@hq_files, @lq_files);
}

# Returns a list of hq_annotated_genotype files that currently exist
sub hq_annotated_genotype_files {
    my $self = shift;

    my @existing_files;
    for my $chromosome (1..22, 'X', 'Y') {
        my $file = $self->hq_annotated_genotype_file_for_chromosome($chromosome);
        if (-s $file) {
            push @existing_files, $file;
        }
    }

    return @existing_files;
}

# Returns a list of lq_annotated_genotype files that currently exist
sub lq_annotated_genotype_files {
    my $self = shift;

    my @existing_files;
    for my $chromosome (1..22, 'X', 'Y') {
        my $file = $self->lq_annotated_genotype_file_for_chromosome($chromosome);
        if (-s $file) {
            push @existing_files, $file;
        }
    }

    return @existing_files;
}

# The file containing the high sensitivity genotype for this sample, pre annotation
sub hq_genotype_file_for_chromosome {
    my $self = shift;
    my $chromosome = shift;
    return $self->latest_build_directory. "/hq_genotype_$chromosome.tsv";
}

# The file containing the high sensitivity genotype for this sample, post annotation
sub hq_annotated_genotype_file_for_chromosome {
    my $self = shift;
    my $chromosome = shift;
    return $self->latest_build_directory . "/hq_annotated_genotype_$chromosome.tsv";
}

# The file containing the low sensitivity genotype for this sample, pre annotation
sub lq_genotype_file_for_chromosome {
    my $self = shift;
    my $chromosome = shift;
    return $self->latest_build_directory . "/lq_genotype_$chromosome.tsv";
}

# The file containing the low sensitivity genotype for this sample, post annotation
sub lq_annotated_genotype_file_for_chromosome {
    my $self = shift;
    my $chromosome = shift;
    return $self->latest_build_directory . "/lq_annotated_genotype_$chromosome.tsv";
}

# The maf file produced from high sensitivity genotypes
sub hq_maf_file {
    my $self = shift;
    return $self->latest_build_directory . "/hq_maf_file.maf";
}

# The file containing the low sensitivity genotype for this sample, pre annotation
sub lq_maf_file {
    my $self = shift;
    return $self->latest_build_directory . "/lq_maf_file.maf";
}

# Checks to see if the child model passed in is valid
sub _is_valid_child{
    my ($self, $child) = @_;
    return grep { $child->technology =~ /$_/i } $self->valid_child_types;
}

# Returns the valid types that this model (as a composite model) can have as children
sub valid_child_types{
    my $self = shift;
    return qw/polyscan polyphred/;
}

# Returns the default location where this model should live on the file system
sub resolve_data_directory {
    my $self = shift;

    my $base_directory = "/gscmnt/834/info/medseq/combine_variants/";
    my $name = $self->name;
    my $data_dir = "$base_directory/$name/";
    
    # Remove spaces so the directory isnt a pain
    $data_dir=~ s/ /_/;

    return $data_dir;
}

sub child_models{
    my $self = shift;
    return $self->from_models;
}

# Returns the parameterized model associated with this composite
sub get_models_for_type {   
    my ($self, $type) = @_;

    my @children = $self->child_models;

    my @models = grep { $_->type =~ $type } @children;

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

# Accessor for the high sensitivity polyphred model
sub hq_polyphred_model {
    my $self = shift;

    my @polyphred_models = $self->polyphred_models;
    for my $model (@polyphred_models) {
        if (($model->technology eq 'polyphred')&&($model->sensitivity eq 'high')) {
            return $model;
        }
    }

    $self->error_message("No hq polyphred model found");
    return undef;
}

# Accessor for the low sensitivity polyphred model
sub lq_polyphred_model {
    my $self = shift;

    my @polyphred_models = $self->polyphred_models;
    for my $model (@polyphred_models) {
        if (($model->technology eq 'polyphred')&&($model->sensitivity eq 'low')) {
            return $model;
        }
    }

    $self->error_message("No lq polyphred model found");
    return undef;
}

# Accessor for the high sensitivity polyscan model
sub hq_polyscan_model {
    my $self = shift;

    my @polyscan_models = $self->polyscan_models;
    for my $model (@polyscan_models) {
        if (($model->technology eq 'polyscan')&&($model->sensitivity eq 'high')) {
            return $model;
        }
    }

    $self->error_message("No hq polyscan model found");
    return undef;
}

# Accessor for the low sensitivity polyscan model
sub lq_polyscan_model {
    my $self = shift;

    my @polyscan_models = $self->polyscan_models;
    for my $model (@polyscan_models) {
        if (($model->technology eq 'polyscan')&&($model->sensitivity eq 'low')) {
            return $model;
        }
    }

    $self->error_message("No lq polyscan model found");
    return undef;
}

# Grabs the next sample genotype from the model, or returns undef if the model is not defined
sub next_or_undef{
    my ($self, $model) = @_;
    return undef unless $model;
    return $model->next_sample_genotype;
}

# Calls combine_variants_for_set to combine variants for both hq and lq models
sub combine_variants{ 
    my $self = shift;

    my $start = new Benchmark;

    my $hq_genotype_file_method = 'hq_genotype_file_for_chromosome';
    my ($hq_polyscan_model) = $self->hq_polyscan_model;
    my ($hq_polyphred_model) = $self->hq_polyphred_model;
    $self->combine_variants_for_set($hq_polyscan_model, $hq_polyphred_model, $hq_genotype_file_method);

    my $lq_genotype_file_method = 'lq_genotype_file_for_chromosome';
    my ($lq_polyscan_model) = $self->lq_polyscan_model;
    my ($lq_polyphred_model) = $self->lq_polyphred_model;
    $self->combine_variants_for_set($lq_polyscan_model, $lq_polyphred_model, $lq_genotype_file_method);

    my $stop = new Benchmark;

    my $time = timestr(timediff($stop, $start));
    $self->status_message("Total combine variants time: $time");
    return 1;
}

# Given a set of hq or lq polyscan and polyphred models, run the combine variants logic
sub combine_variants_for_set{
    my ($self, $polyscan_model, $polyphred_model, $genotype_file_method) = @_;

    my $whole_start = new Benchmark;

    unless($polyscan_model || $polyphred_model){
        $self->error_message("No child models to combine variants on!");
        die;
    }

    my $polyscan_genotype = $self->next_or_undef($polyscan_model);
    my $polyphred_genotype = $self->next_or_undef($polyphred_model);

    my $while_start = new Benchmark;
    
    # While there is data for at least one of the two,
    # Pass them into generate_genotype to make the decisions

    my $current_chromosome = '';
    my ($ofh, $genotype_file);
    while ($polyphred_genotype or $polyscan_genotype){
        my ($chr1, $start1, $sample1, $chr2, $start2, $sample2);
        if ($polyscan_genotype){
            $chr1 = $polyscan_genotype->{chromosome};
            $start1 = $polyscan_genotype->{begin_position};
            $sample1 = $polyscan_genotype->{sample_name};
        }
        if ($polyphred_genotype){
            $chr2 = $polyphred_genotype->{chromosome};
            $start2 = $polyphred_genotype->{begin_position};
            $sample2 = $polyphred_genotype->{sample_name};
        }
        my $cmp = compare_position_and_sample($chr1, $start1, $sample1, $chr2, $start2, $sample2);
        unless (defined $cmp){
            if ($polyphred_genotype and !$polyscan_genotype){
                $cmp = 1;
            }elsif( $polyscan_genotype and !$polyphred_genotype){
                $cmp = -1;
            }
        }
        if ($cmp < 0){

            my $genotype = $self->generate_genotype($polyscan_genotype, undef);
            if ($genotype->{chromosome} ne $current_chromosome) {
                $ofh->close if $ofh;
                $current_chromosome = $genotype->{chromosome};
                $genotype_file = $self->$genotype_file_method($current_chromosome);
                $ofh = IO::File->new("> $genotype_file");
            }
            $ofh->print($self->format_genotype_line($genotype));
            $polyscan_genotype = $self->next_or_undef($polyscan_model);

        }elsif ($cmp > 0){

            my $genotype = $self->generate_genotype(undef, $polyphred_genotype);
            if ($genotype->{chromosome} ne $current_chromosome) {
                $ofh->close if $ofh;
                $current_chromosome = $genotype->{chromosome};
                $genotype_file = $self->$genotype_file_method($current_chromosome);
                $ofh = IO::File->new("> $genotype_file");
            }
            $ofh->print($self->format_genotype_line($genotype));
            $polyphred_genotype = $self->next_or_undef($polyphred_model);

        }elsif ($cmp == 0){

            my $genotype = $self->generate_genotype($polyscan_genotype, $polyphred_genotype);    
            if ($genotype->{chromosome} ne $current_chromosome) {
                $ofh->close if $ofh;
                $current_chromosome = $genotype->{chromosome};
                $genotype_file = $self->$genotype_file_method($current_chromosome);
                $ofh = IO::File->new("> $genotype_file");
            }
            $ofh->print($self->format_genotype_line($genotype));
            $polyphred_genotype = $self->next_or_undef($polyphred_model);
            $polyscan_genotype = $self->next_or_undef($polyscan_model);

        }else{
            $self->error_message("Could not compare polyphred and polyscan genotypes:".Dumper $polyphred_genotype.Dumper $polyscan_genotype);
            die;
        }
    }

    $ofh->close if $ofh;

    my $stop = new Benchmark;

    my $whole_time = timestr(timediff($stop, $whole_start));
    my $while_time = timestr(timediff($stop, $while_start));

    $self->status_message("Total $genotype_file combine variants time: $whole_time");
    $self->status_message("$genotype_file combine variants time minus setup input: $while_time");

    return 1;
}

# Decide whether to trust the polyscan or polyphred genotype based upon logic,
# Return the asnwer that we trust
sub generate_genotype{
    my ($self, $scan_g, $phred_g) = @_;

    # This is the value at which we will trust polyscan over polyphred when running "combine variants" logic
    my $min_polyscan_score = 75;

    # If there is data from both polyscan and polyphred, decide which is right
    if ($scan_g && $phred_g){
        if ( $scan_g->{allele1} eq $phred_g->{allele1} and $scan_g->{allele2} eq $phred_g->{allele2} ){
            $scan_g->{polyphred_score} = $phred_g->{score};
            $scan_g->{polyphred_read_count} = $phred_g->{read_count};
            $scan_g->{polyscan_score} = $scan_g->{score};
            $scan_g->{polyscan_read_count} = $scan_g->{read_count};

            return $scan_g;

        }elsif ($scan_g->{score} > $min_polyscan_score){
            return $self->generate_genotype($scan_g, undef);
        }else{
            return $self->generate_genotype(undef, $phred_g);
        }

        # If data is available for only one of polyphred or polyscan, trust it
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

# Format a hash into a printable line
sub format_genotype_line{
    my ($self, $genotype) = @_;

    return join("\t", map { $genotype->{$_} } $self->genotype_columns)."\n";
}

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

# Format a line into a hash
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

sub parse_annotated_genotype_line {
    my ($self, $line) = @_;

    my @columns = split("\t", $line);
    my @headers = $self->annotated_columns;

    my $hash;
    for my $header (@headers) {
        $hash->{$header} = shift(@columns);
    }

    return $hash;
}

# List of columns present in the combine variants output
sub genotype_columns{
    my $self = shift;
    return qw(
    chromosome 
    begin_position
    end_position
    sample_name
    gene
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
    polyscan_score 
    polyphred_score
    read_type
    con_pos
    filename
    );
}

sub annotated_columns{
    my $self = shift;
    return qw(
    chromosome 
    begin_position
    end_position
    sample_name
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
    polyscan_score 
    polyphred_score
    transcript_name
    transcript_source
    c_position
    trv_type
    priority
    gene_name
    intensity
    detection
    amino_acid_length
    amino_acid_change
    variations 
    );
}

# Meaningful names for the maf columns to us for hashes etc
# TODO:... sample will go in either the tumor sample barcode or normal sample barcode depending if it is normal or tumor...
# same is true of allele1 and allele2
# FIXME This is pretty much jacked up because xshi's script seems to be lacking 4 colums and possily be in the wrong order in some cases
sub maf_columns {
    my $self = shift;
    return qw(
    gene
    entrez_gene_id
    center
    ncbi_build
    chromosome
    begin_position
    end_position
    strand
    variant_classification
    variation_type
    reference
    tumor_seq_allele1
    tumor_seq_allele2
    dbsnp_rs
    dbsnp_val_status
    tumor_sample_barcode
    matched_norm_sample_barcode
    match_norm_seq_allele1
    match_norm_seq_allele2
    tumor_validation_allele1
    tumor_validation_allele2
    match_norm_validation_allele1
    match_norm_validation_allele2
    verification_status
    validation_status
    mutation_status
    cosmic_comparison
    omim_comparison
    transcript_name
    trv_type
    prot_string
    c_position
    pfam_domain
    ); #  c_position = prot_string_short
    # called_classification = c_position
}

# actual printed header of the MAF
sub maf_header {
    my $self = shift;
    return"Hugo_Symbol\tEntrez_Gene_Id\tCenter\tNCBI_Build\tChromosome\tStart_position\tEnd_position\tStrand\tVariant_Classification\tVariant_Type\tReference_Allele\tTumor_Seq_Allele1\tTumor_Seq_Allele2\tdbSNP_RS\tdbSNP_Val_Status\tTumor_Sample_Barcode\tMatched_Norm_Sample_Barcode\tMatch_Norm_Seq_Allele1\tMatch_Norm_Seq_Allele2\tTumor_Validation_Allele1\tTumor_Validation_Allele2\tMatch_Norm_Validation_Allele1\tMatch_Norm_Validation_Allele2\tVerification_Status\tValidation_Status\tMutation_Status\tCOSMIC_COMPARISON(ALL_TRANSCRIPTS)\tOMIM_COMPARISON(ALL_TRANSCRIPTS)\tTranscript\tCALLED_CLASSIFICATION\tPROT_STRING\tPROT_STRING_SHORT\tPFAM_DOMAIN";
}

# Reads from the high sensitivity post annotation genotype file and returns the next line as a hash
# Optionally takes a chromosome and position range and returns only genotypes in that range
sub next_hq_annotated_genotype_in_range{
    my $self = shift;
    return $self->next_hq_annotated_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_hq_annotated_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{begin_position}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{begin_position}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

# Reads from the low sensitivity post annotation genotype file and returns the next line as a hash
# Optionally takes a chromosome and position range and returns only genotypes in that range
sub next_lq_annotated_genotype_in_range{
    my $self = shift;
    return $self->next_lq_annotated_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_hq_annotated_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{begin_position}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{begin_position}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

# Creates the model if it doesnt exist and returns it either way
# TODO may not need this if we can guarantee the processing profile is there
sub get_or_create {
    my ($class , %p) = @_;
    my $subject_name = $p{subject_name};
    my $data_directory = $p{data_directory};
    my $subject_type = $p{subject_type};
    $subject_type ||= 'sample_group';

    unless (defined($subject_name)) {
        $class->error_message("Insufficient params supplied to get_or_create");
        return undef;
    }
    my $pp_name = 'combine_variants';
    my $name = "$subject_name.$pp_name";

    my $model = Genome::Model::CombineVariants->get(name => $name);

    unless ($model) {
        # TODO: More params...
        my $pp = Genome::ProcessingProfile::CombineVariants->get();

        # Make the processing profile if it doesnt exist
        unless ($pp) {
            $pp = Genome::ProcessingProfile::CombineVariants->create(name => $pp_name);
        }
        
        my $create_command = Genome::Model::Command::Create::Model->create(
            model_name => $name,
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
    }

    return $model;
}

# Calls write_maf_file to create both pre annotation maf files
sub write_pre_annotation_maf_files { #TODO  fix maf file writing, remove range
    my $self = shift;

    $self->write_maf_file('next_hq_genotype_in_range', $self->hq_maf_file);

    $self->write_maf_file('next_lq_genotype_in_range', $self->lq_maf_file);

    return 1;
}

# Calls write_maf_file to create both pre annotation maf files
sub write_post_annotation_maf_files {  #TODO  fix maf file writing, remove range
    my $self = shift;

    $self->write_maf_file('next_hq_annotated_genotype_in_range', $self->hq_maf_file);

    $self->write_maf_file('next_lq_annotated_genotype_in_range', $self->lq_maf_file);

    return 1;
}

# Genotype method should be 'next_hq_annotated_genotype_in_range' 'next_hq_genotype_in_range'
# or the lq equivilants depending on if you want a annotated maf file or pre-annotation maf file
sub write_maf_file{
    my $self = shift;
    my ($genotype_method, $maf_file, $chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    $chrom_start ||= 0;
    $pos_start ||=0;
    $chrom_stop ||= 100;
    $pos_stop ||= 1e12;
    $genotype_method ||= 'next_hq_annotated_genotype_in_range';
    $maf_file ||= $self->hq_maf_file;


    # Print maf header
    my $header = $self->maf_header;
    my $fh = IO::File->new(">$maf_file");
    print $fh "$header\n";

    # Print maf data
    my @current_sample_basename_genotypes;
    my $current_sample_basename;
    while (my $genotype = $self->$genotype_method($chrom_start, $pos_start, $chrom_stop, $pos_stop)){

        my ($sample_basename) = $genotype->{sample_name} =~ /(.*)(t|n)$/;
        $current_sample_basename ||= $sample_basename;

        my $tumor_genotype;
        my $normal_genotype;

        if ($sample_basename eq $current_sample_basename){
            push @current_sample_basename_genotypes, $genotype;
        }else{
            if (@current_sample_basename_genotypes > 2){
                $self->error_message("more than two genotypes with same sample basename, continuing anyway... ".Dumper @current_sample_basename_genotypes);
            }

            my $maf_line = $self->format_maf_line_from_matched_samples(@current_sample_basename_genotypes);
            if ($maf_line){
                $fh->print($maf_line);
            }else{
                $self->error_message("no maf line generated from matched sample genotypes\n".Dumper @current_sample_basename_genotypes);
            }

            @current_sample_basename_genotypes = ();
            $current_sample_basename = $sample_basename;
            push @current_sample_basename_genotypes, $genotype;
        }
    }

    my $last_line = $self->format_maf_line_from_matched_samples(@current_sample_basename_genotypes);
    $fh->print($last_line) if $last_line;

    return 1;
}

# Takes in an array containing normal and tumor genotypes
# Returns a printable MAF line that contains the matched tumor/normal information
sub format_maf_line_from_matched_samples{
    my ($self, @matched_sample_genotypes) = @_;

    my $tumor_genotype;
    my $normal_genotype;
    for my $sample_genotype (@matched_sample_genotypes){
        $tumor_genotype = $sample_genotype if $sample_genotype->{sample_name} =~ /t$/;
        $normal_genotype = $sample_genotype if $sample_genotype->{sample_name} =~ /n$/;
    }

    if ($tumor_genotype){
        $tumor_genotype->{center} = "genome.wustl.edu";
        if ($normal_genotype){
            $tumor_genotype->{match_norm_seq_allele1} = $normal_genotype->{allele1};
            $tumor_genotype->{match_norm_seq_allele2} = $normal_genotype->{allele2};
        }else{
            $tumor_genotype->{match_norm_seq_allele1} = 'N/A';
            $tumor_genotype->{match_norm_seq_allele2} = 'N/A';
        }
        $tumor_genotype->{tumor_seq_allele1} = $tumor_genotype->{allele1};
        $tumor_genotype->{tumor_seq_allele2} = $tumor_genotype->{allele2};

        my $line = join("\t", map{$tumor_genotype->{$_} || 'N/A'} $self->maf_columns)."\n";
        return $line;
    }
    return undef;
}

# Compares chromosome, position, and sample name
sub compare_position_and_sample {
    my ($chr1, $pos1, $sample1, $chr2, $pos2, $sample2) = @_;
    unless (defined $chr1 and defined $chr2 and defined $pos1 and defined $pos2 and defined $sample1 and defined $sample2){
        return undef;
    }
    my $pos_cmp = compare_position($chr1, $pos1, $chr2, $pos2);
    if ($pos_cmp < 0){
        return -1;
    }elsif ($pos_cmp == 0){
        return $sample1 cmp $sample2;
    }else{
        return 1;
    }
}

sub annotate_variants {
    my $self = shift;

    my @input_files = $self->genotype_files;
    my @output_files;
    for my $in (@input_files){
        my $out = $in;
        $out =~ s/genotype/annotated_genotype/;
        push @output_files, $out;
    }
    if (1) { # workflow switch
        
        require Workflow::Simple;

        my $m = Workflow::Model->create(
            name => 'annotate variants wrapper',
            input_properties => [qw/quality chromosome directory/],
            output_properties => [qw/result/]
        );

        $m->parallel_by('quality');

        my $op = $m->add_operation(
            name => 'annotate variants',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::CombineVariants::AnnotateVariants')
        );
        
        $op->parallel_by('chromosome');
        
        foreach my $input_property (@{ $m->operation_type->input_properties }) {
            $m->add_link(
                left_operation => $m->get_input_connector,
                left_property => $input_property,
                right_operation => $op,
                right_property => $input_property,
            );
        }
        
        $m->add_link(
            left_operation => $op,
            left_property => 'result',
            right_operation => $m->get_output_connector,
            right_property => 'result',
        );


        my $output = Workflow::Simple::run_workflow_lsf(
            $m,
            'chromosome' => [1..22,'X','Y'],
            quality => ['hq','lq'],
            directory => $self->latest_build_directory,
        );
 
        unless ($output) {
            $self->error_message("Annotate variants failed in workflow");
            foreach my $error (@Workflow::Simple::ERROR) {
                print STDERR Data::Dumper->new([$error],['error'])->Dump;
            }
            die;
        }
        
    } else {
        # If we dont want to run workflow... add code here
    }

}

sub compare_position{
    my ($chr1, $pos1, $chr2, $pos2) = @_;
    unless (defined $chr1 and defined $chr2 and defined $pos1 and defined $pos2){
        return undef;
    }
    my $chr_cmp = "$chr1" cmp "$chr2";  #Using cmp because this is how the setup input files are sorted
    if ($chr_cmp < 0){
        return -1;
    }elsif ($chr_cmp == 0){
        return $pos1 <=> $pos2;
    }else{
        return 1;
    }
}

1;
