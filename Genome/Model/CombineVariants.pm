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

sub hq_annotated_genotype_file {
    my $self = shift;
    return $self->model_directory . "/hq_annotated_genotype.tsv";
}

sub lq_genotype_file {
    my $self = shift;
    return $self->model_directory . "/lq_genotype.tsv";
}

sub lq_annotated_genotype_file {
    my $self = shift;
    return $self->model_directory . "/lq_annotated_genotype.tsv";
}

# Returns current directory where the microarray data is housed
sub base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/combine_variants/';
}

sub _is_valid_child{
    my ($self, $child) = @_;
    return grep { $child->technology =~ /$_/i } $self->valid_child_types;
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
        if ( $current_hq_chromosome != $hq_genotype->{chromosome}){
            $current_hq_chromosome = $hq_genotype->{chromosome};
            $db_chrom = $schema->resultset('Chromosome')->find(
                {chromosome_name => $hq_genotype->{chromosome} },
            );
            $annotator = Genome::VariantAnnotator->new(
                transcript_window => $db_chrom->transcript_window(range => 0),
                variation_window => $db_chrom->variation_window(range => 0),
            );
        }

        my @annotations;
        if (lc $hq_genotype->{variation_type} eq 'indel'){

            @annotations = $annotator->prioritized_transcripts_for_snp( # TODO make this back into indel
                start => $hq_genotype->{start},
                stop => $hq_genotype->{stop},
                reference => $hq_genotype->{allele1},
                variant => $hq_genotype->{allele2},
                chromosome => $hq_genotype->{chromosome},
            );
        }elsif (lc $hq_genotype->{variation_type} eq 'snp'){
            @annotations = $annotator->prioritized_transcripts_for_snp(
                start => $hq_genotype->{start},
                reference => $hq_genotype->{allele1},
                variant => $hq_genotype->{allele2},
                chromosome => $hq_genotype->{chromosome},
                stop => $hq_genotype->{stop},
            );
        }

        for my $annotation (@annotations){
            $annotation->{variations} = join (",",keys %{$annotation->{variations}});
            my %combo = (%$hq_genotype, %$annotation);
            $hq_ofh->print($self->format_annotated_genotype_line(\%combo));
        }
    }

    ####lq
    my $lq_post_annotation_file = $self->lq_annotated_genotype_file;
    my $lq_ofh = IO::File->new("> $lq_post_annotation_file");

    my $current_lq_chromosome=0;
    while (my $lq_genotype = $self->next_lq_genotype){

        #NEW ANNOTATOR IF WE'RE ON A NEW CHROMOSOME
        if ( $current_lq_chromosome != $lq_genotype->{chromosome}){
            $current_lq_chromosome = $lq_genotype->{chromosome};
            $db_chrom = $schema->resultset('Chromosome')->find(
                {chromosome_name => $lq_genotype->{chromosome} },
            );
            $annotator = Genome::VariantAnnotator->new(
                transcript_window => $db_chrom->transcript_window(range => 0),
                variation_window => $db_chrom->variation_window(range => 0),
            );
        }

        my @annotations;
        if (lc $lq_genotype->{variation_type} eq 'indel'){
            @annotations = $annotator->transcripts_for_snp( # TODO Make this back into indel... but the function doesnt exist
                start => $lq_genotype->{start},
                reference => $lq_genotype->{allele1},
                variant => $lq_genotype->{allele2},
                chromosome => $lq_genotype->{chromosome},
                stop => $lq_genotype->{stop},
            );
        }elsif (lc $lq_genotype->{variation_type} eq 'snp'){
            @annotations = $annotator->transcripts_for_snp(
                start => $lq_genotype->{start},
                reference => $lq_genotype->{allele1},
                variant => $lq_genotype->{allele2},
                chromosome => $lq_genotype->{chromosome},
                stop => $lq_genotype->{stop},
            );
        }
        for my $annotation (@annotations){
            $annotation->{variations} = join (",",keys %{$annotation->{variations}});
            my %combo = (%$lq_genotype, %$annotation);
            $lq_ofh->print($self->format_annotated_genotype_line(\%combo));
        }
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

# Creates the model if it doesnt exist and returns it either way
# TODO may not need this if we can guarantee the processing profile is there
sub get_or_create {
    my ($class , %p) = @_;
    my $name = $p{name};


    unless (defined($name)) {
        $class->error_message("Insufficient params supplied to get_or_create");
        return undef;
    }

    my $model = Genome::Model::CombineVariants->get(name => $name);

    unless ($model) {
        # TODO: More params...
        my $pp = Genome::ProcessingProfile::CombineVariants->get();

        # Make the processing profile if it doesnt exist
        unless ($pp) {
            $pp = Genome::ProcessingProfile::CombineVariants->create(name => 'combine variants');
        }

        $model = Genome::Model::CombineVariants->create(name => $name,
            processing_profile => $pp);
    }

    return $model;
}

=cut

sub write_maf_file{
    my $self = shift;
    my $header = join("\t", $self->columns)."\n";
    print $header;
    while (my $genotype = $self->next_hq_genotype){
        print join("\t", map { $genotype->{$_} } $self->columns);
    }

    use lib '/gscuser/xshi/svn/perl_modules/';
    use MG::Analysis::VariantAnnotation;

    MPSampleData::DBI::myinit("dbi:Oracle:dwrac","mguser_prd"); #switch to production by default

    while (my $genotype = $self->next_hq_genotype){

        my $Hugo_Symbol
        my $Entrez_Gene_Id
        my $Center
        my $NCBI_Build
        my $Chromosome = $genotype->{chromosome};
        my $Start_position = $genotype->{start};
        my $End_position = $genotype->{stop};
        my $Strand
        my $Variant_Classification
        my $Variant_Type
        my $Reference_Allele
        my $Tumor_Seq_Allele1
        my $Tumor_Seq_Allele2
        my $dbSNP_RS
        my $dbSNP_Val_Status
        my $Tumor_Sample_Barcode
        my $Matched_Norm_Sample_Barcode
        my $Match_Norm_Seq_Allele1
        my $Match_Norm_Seq_Allele2
        my $Tumor_Validation_Allele1
        my $Tumor_Validation_Allele2
        my $Match_Norm_Validation_Allele1
        my $Match_Norm_Validation_Allele2
        my $Verification_Status
        my $Validation_Status
        my $Mutation_Status
        my $a1
        $NCBI_Build=36;
        $Mutation_Status="Somatic" if($Mutation_Status =~ /s/i);

#     my $tu_sample=$Tumor_Sample_Barcode;
#     $tu_sample =~ s/t//;
#     my $grep = `grep $tu_sample ~xshi/work/TCGA/MAF/CURRENT/sample_96`;

#      ($Tumor_Sample_Barcode,$Matched_Norm_Sample_Barcode)=split(/\t|\n/,$grep)  if($grep);

    $line="$Hugo_Symbol\t$Entrez_Gene_Id\t$Center\t$NCBI_Build\t$Chromosome\t$Start_position\t$End_position\t$Strand\t$Variant_Classification\t$Variant_Type\t$Reference_Allele\t$Tumor_Seq_Allele1\t$Tumor_Seq_Allele2\t$dbSNP_RS\t$dbSNP_Val_Status\t$Tumor_Sample_Barcode\t$Matched_Norm_Sample_Barcode\t$Match_Norm_Seq_Allele1\t$Match_Norm_Seq_Allele2\t$Tumor_Validation_Allele1\t$Tumor_Validation_Allele2\t$Match_Norm_Validation_Allele1\t$Match_Norm_Validation_Allele2\t$Verification_Status\t$Validation_Status\t$Mutation_Status\t$a1";

    my
    $self=MG::Analysis::VariantAnnotation->new(type=>$Variant_Type,chromosome=>$Chromosome,start=>$Start_position,end=>$End_position,filter => 1);
    my $proper_allele2 = ($Reference_Allele ne $Tumor_Seq_Allele2) ?  $Tumor_Seq_Allele2 : $Tumor_Seq_Allele1;
    my
    $result=$self->annotate(allele1=>$Reference_Allele,allele2=>$proper_allele2,gene=>$Hugo_Symbol);

#getting the results
    my $transcript=$self->{annotation}->{$Hugo_Symbol}->{choice} if(exists
        $self->{annotation}->{$Hugo_Symbol}->{choice} && defined
        $self->{annotation}->{$Hugo_Symbol}->{choice});
    if(defined $transcript) {
#pro_str is the amino acid change (eg. p.W111R)

        my $amino_change = $self->{annotation}->{$Hugo_Symbol}->{transcript}->{$transcript}->{pro_str};
        $line.="\t$transcript";
        $line.="\t".$self->{annotation}->{$Hugo_Symbol}->{transcript}->{$transcript}->{trv_type}; 
        $line.="\t$amino_change";

        $line.="\tc.".$self->{annotation}->{$Hugo_Symbol}->{transcript}->{$transcript}->{c_position};
#     my $prediction=$self->get_prediction($transcript,$amino_change,1,1);
#     $line.="\t".$prediction->{sift};
#     $line.="\t".$prediction->{polyphen};
    }


    print $ofh $line,"\n";
}

$fh->close;
$ofh->close;

}


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

1;
