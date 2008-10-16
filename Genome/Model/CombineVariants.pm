package Genome::Model::CombineVariants;

use strict;
use warnings;

use IO::File;
use Genome;
use Data::Dumper;
use Genome::VariantAnnotator;
use Genome::DB::Schema;
use Genome::Utility::ComparePosition qw/compare_position compare_chromosome/;

class Genome::Model::CombineVariants{
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
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    my $data_dir = $self->data_directory;
    # If the data directory was not supplied, resolve what it should be by default
    unless ($data_dir) {
        $data_dir= $self->resolve_data_directory;
        $self->data_directory($data_dir);
    }

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

    return $self;
}

sub build_subclass_name {
    return 'combine_variants';
}

# The file containing the genotype for this sample
sub hq_genotype_file {
    my $self = shift;
    return $self->data_directory . "/hq_genotype.tsv";
}

sub hq_annotated_genotype_file {
    my $self = shift;
    return $self->data_directory . "/hq_annotated_genotype.tsv";
}

sub lq_genotype_file {
    my $self = shift;
    return $self->data_directory . "/lq_genotype.tsv";
}

sub lq_annotated_genotype_file {
    my $self = shift;
    return $self->data_directory . "/lq_annotated_genotype.tsv";
}

sub maf_file {
    my $self = shift;
    return $self->data_directory . "/maf_file.maf";
}

sub _is_valid_child{
    my ($self, $child) = @_;
    return grep { $child->technology =~ /$_/i } $self->valid_child_types;
}

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

sub annotate_variants {
    my ($self) = @_;

    my $schema = Genome::DB::Schema->connect_to_dwrac;
 
    $self->error_message("Can't connect to dwrac")
        and return unless $schema;
    
    my $annotator;
    my $db_chrom;

    ####hq
    my $hq_post_annotation_file = $self->hq_annotated_genotype_file;
    my $hq_ofh = IO::File->new("> $hq_post_annotation_file");

    my $current_hq_chromosome=0;
    while (my $hq_genotype = $self->next_hq_genotype){
        
        #NEW ANNOTATOR IF WE'RE ON A NEW CHROMOSOME
        if ( compare_chromosome($current_hq_chromosome,$hq_genotype->{chromosome}) != 0 ){
            $current_hq_chromosome = $hq_genotype->{chromosome};
            $db_chrom = $schema->resultset('Chromosome')->find(
                {chromosome_name => $hq_genotype->{chromosome} },
            );
            $annotator = Genome::VariantAnnotator->new(
                transcript_window => $db_chrom->transcript_window(range => 50000),
                variation_window => $db_chrom->variation_window(range => 50000),
            );
        }
        
        $self->print_prioritized_annotation($hq_genotype, $annotator, $hq_ofh);
    }

    ####lq
    my $lq_post_annotation_file = $self->lq_annotated_genotype_file;
    my $lq_ofh = IO::File->new("> $lq_post_annotation_file");

    my $current_lq_chromosome=0;
    while (my $lq_genotype = $self->next_lq_genotype){

        #NEW ANNOTATOR IF WE'RE ON A NEW CHROMOSOME
        if ( compare_chromosome($current_lq_chromosome, $lq_genotype->{chromosome}) != 0){
            $current_lq_chromosome = $lq_genotype->{chromosome};
            $db_chrom = $schema->resultset('Chromosome')->find(
                {chromosome_name => $lq_genotype->{chromosome} },
            );
            $annotator = Genome::VariantAnnotator->new(
                transcript_window => $db_chrom->transcript_window(range => 0),
                variation_window => $db_chrom->variation_window(range => 0),
            );
        }

        $self->print_prioritized_annotation($lq_genotype, $annotator, $lq_ofh);
    }

    $lq_ofh->close;
    $hq_ofh->close;

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
        unless (defined($variant)) {
            $DB::single=1;
        }
        my @annotations;
        if ($genotype->{variation_type} =~ /ins|del/i){
            @annotations = $annotator->prioritized_transcripts_for_snp( # TODO Make this back into indel... but the function doesnt exist
                start => $genotype->{start},
                reference => $genotype->{reference},
                variant => $variant,
                chromosome_name => $genotype->{chromosome},
                stop => $genotype->{stop},
                type => $genotype->{variation_type},
            );
        }elsif ($genotype->{variation_type} =~ /snp/i){
            @annotations = $annotator->prioritized_transcripts_for_snp(
                start => $genotype->{start},
                reference => $genotype->{reference},
                variant => $variant,
                chromosome_name => $genotype->{chromosome},
                stop => $genotype->{stop},
                type => $genotype->{variation_type},
            );
        }
        else {
            $self->error_message("Unrecognized variation_type " . $genotype->{variation_type});
            return undef;
        }

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


# Calls combine_variants_for_set to combine variants for both hq and lq models
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

    return 1;
}

# Given a set of hq or lq polyscan and polyphred models, run the combine variants logic
sub combine_variants_for_set{
    my ($self, $polyscan_model, $polyphred_model, $genotype_file) = @_;

    my $ofh = IO::File->new("> $genotype_file");
    unless($polyscan_model || $polyphred_model){
        $self->error_message("No child models to combine variants on!");
        die;
    }

    my $polyscan_genotype = $self->next_or_undef($polyscan_model);
    my $polyphred_genotype = $self->next_or_undef($polyphred_model);

    # While there is data for at least one of the two,
    # Pass them into generate_genotype to make the decisions
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
    start 
    stop 
    sample_name
    variation_type
    reference
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    polyscan_score 
    polyphred_score
    );
    # hugo_symbol
    # polyscan_read_count
    # polyphred_read_count
}

sub annotated_columns{
    my $self = shift;
    return qw(
    chromosome 
    start 
    stop 
    sample_name
    variation_type
    reference
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    polyscan_score 
    polyphred_score

    transcript_name
    transcript_source
    strand
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
    # hugo_symbol
    # polyscan_read_count
    # polyphred_read_count
}

# Meaningful names for the maf columns to us for hashes etc
# TODO:... sample will go in either the tumor sample barcode or normal sample barcode depending if it is normal or tumor...
# same is true of allele1 and allele2
# FIXME This is pretty much jacked up because xshi's script seems to be lacking 4 colums and possily be in the wrong order in some cases
sub maf_columns {
    my $self = shift;
    return qw(
    gene_name
    entrez_gene_id
    center
    ncbi_build
    chromosome
    start
    stop
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

# Reads from the hq genotype file and returns the next line
sub next_hq_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
    unless ($self->hq_gfh){
        my $genotype_file = $self->hq_genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->hq_gfh($fh)
    }

    my $line = $self->hq_gfh->getline;
    unless ($line){
        $self->hq_gfh(undef);
        return undef;
    }
    my $genotype = $self->parse_genotype_line($line);

    return $genotype;
}

sub next_hq_genotype_in_range{
    my $self = shift;
    return $self->next_hq_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_hq_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{start}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{start}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

sub next_hq_annotated_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
    unless ($self->hq_agfh){
        my $genotype_file = $self->hq_annotated_genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->hq_agfh($fh)
    }

    my $line = $self->hq_agfh->getline;
    unless ($line){
        $self->hq_agfh(undef);
        return undef;
    }
    my $genotype = $self->parse_annotated_genotype_line($line);

    return $genotype;
}

sub next_hq_annotated_genotype_in_range{
    my $self = shift;
    return $self->next_hq_annotated_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_hq_annotated_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{start}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{start}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

# Reads from the lq genotype file and returns the next line
sub next_lq_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
    unless ($self->lq_gfh){
        my $genotype_file = $self->lq_genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->lq_gfh($fh)
    }

    my $line = $self->lq_gfh->getline;
    unless ($line){
        $self->lq_gfh(undef);
        return undef;
    }
    my $genotype = $self->parse_genotype_line($line);
    return $genotype;
}

sub next_lq_genotype_in_range{
    my $self = shift;
    return $self->next_lq_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_lq_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{start}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{start}, $chrom_stop, $pos_stop) <= 0){
            return $genotype;
        }
    }
}

sub next_lq_annotated_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
    unless ($self->lq_agfh){
        my $genotype_file = $self->lq_annotated_genotype_file;
        my $fh = IO::File->new("< $genotype_file");
        return undef unless $fh;
        $self->lq_agfh($fh)
    }

    my $line = $self->lq_agfh->getline;
    unless ($line){
        $self->lq_agfh(undef);
        return undef;
    }
    my $genotype = $self->parse_annotated_genotype_line($line);
    return $genotype;
}

sub next_lq_annotated_genotype_in_range{
    my $self = shift;
    return $self->next_lq_annotated_genotype unless @_;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop) = @_;
    while (my $genotype = $self->next_hq_annotated_genotype){
        return undef unless $genotype;
        if (compare_position($chrom_start, $pos_start, $genotype->{chromosome}, $genotype->{start}) <= 0 and 
            compare_position($genotype->{chromosome}, $genotype->{start}, $chrom_stop, $pos_stop) <= 0){
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
        );

        $model = $create_command->execute();

        unless ($model) {
            $class->error_message("Failed to create model in get_or_create");
            die;
        }
    }

    return $model;
}

sub write_maf_file{
    my $self = shift;
    my ($chrom_start, $pos_start, $chrom_stop, $pos_stop);

    # Print maf header
    my $header = $self->maf_header;
    my $maf_file = $self->maf_file;
    my $fh = IO::File->new(">$maf_file");
    print $fh "$header\n";

    # Print maf data
    while (my $genotype = $self->next_hq_annotated_genotype_in_range($chrom_start, $pos_start, $chrom_stop, $pos_stop)){
        $genotype->{center} = "genome.wustl.edu";
        my $line = join("\t", map{$genotype->{$_} || 'N/A'} $self->maf_columns);
        print $fh "$line\n";
    }

    return 1;
}

=cut
# Matches all sample genotype data into a hash with an entry per
# Sample and position that contains matched normal and tumor data for
# that sample and position
# TODO this really needs to be done once per HQ and LQ
sub get_matched_normal_tumor_hash {
    my $self = shift;

    # Grab all of the sample genotype data for this input
    my @sample_genotype_data;
    while (my $genotype = $self->next_hq_genotype) {
        push @sample_genotype_data, $genotype;
    }

    # TODO: This should already be sorted by position and sample... check
    # Sort if neededa
    my $current_sample;
    while ($sample_genotype_data > 0) {
        # Grab the sample name except for the last character which will denote normal or tumor
        unless (defined($current_sample)) {
            $current_sample = $sample_genotype_data[0];
        }


    }


}
=cut

1;
