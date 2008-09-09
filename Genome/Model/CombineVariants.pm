package Genome::Model::CombineVariants;

use strict;
use warnings;

use IO::File;
use Genome;
use Data::Dumper;
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

# Returns current directory where the microarray data is housed
sub base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/combine_variants/';
}

sub _is_valid_child{
    my ($self, $child) = @_;
    return grep { $child->type =~ /$_/i } $self->valid_child_types;
}

sub valid_child_types{
    my $self = shift;
    return qw/hq_polyscan hq_polyphred lq_polyscan lq_polyphred/;
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
        if ($model->type =~ 'hq') {
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
        if ($model->type =~ 'lq') {
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
        if ($model->type =~ 'hq') {
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
        if ($model->type =~ 'lq') {
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

    my $hq_genotype_file = $self->hq_genotype_file;
    my ($hq_polyscan_model) = $self->hq_polyscan_model;
    my ($hq_polyphred_model) = $self->hq_polyphred_model;
    $self->combine_variants_for_set($hq_polyscan_model, $hq_polyphred_model, $hq_genotype_file);

    my $lq_genotype_file = $self->lq_genotype_file;
    my ($lq_polyscan_model) = $self->lq_polyscan_model;
    my ($lq_polyphred_model) = $self->lq_polyphred_model;
    $self->combine_variants_for_set($lq_polyscan_model, $lq_polyphred_model, $lq_genotype_file);
}

# Given a set of hq or lq polyscan and polyphred models, run the combine variants logic
sub combine_variants_for_set{
    my ($self, $polyscan_model, $polyphred_model, $genotype_file) = @_;

    my $ofh = IO::File->new("> $genotype_file");
    unless($polyscan_model || $polyphred_model){
        $self->error_message("No child models to combine variants on!");
        die;
    }

    $polyscan_model->reset_gfh;
    $polyphred_model->reset_gfh;
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
}

# Decide whether to trust the polyscan or polyphred genotype based upon logic,
# Return the asnwer that we trust
sub generate_genotype{
    my ($self, $scan_g, $phred_g) = @_;

    # If there is data from both polyscan and polyphred, decide which is right
    if ($scan_g && $phred_g){
        if ( $scan_g->{allele1} eq $phred_g->{allele1} and $scan_g->{allele2} eq $phred_g->{allele2} ){
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
    return join("\t", map { $genotype->{$_} } $self->columns)."\n";
}

# List of columns present in the combine variants output
sub columns{
    my $self = shift;
    return qw(
    chromosome 
    start 
    stop 
    sample_name
    hugo_symbol
    variant_type
    allele1 
    allele1_type 
    allele2 
    allele2_type 
    polyscan_score 
    polyphred_score
    polyscan_read_count
    polyphred_read_count
    );
}

# Reads from the hq genotype file and returns the next line
sub next_hq_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
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

# Reads from the lq genotype file and returns the next line
sub next_lq_genotype{
    my $self = shift;

    # Open the file handle if it hasnt been
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

sub write_maf_file{
    my $self = shift;
    my $header = join("\t", $self->columns)."\n";
    print $header;
    while (my $genotype = $self->next_hq_genotype){
        print join("\t", map { $genotype->{$_} } $self->columns);
    }

=cut
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
=cut

}

1;
