package Genome::Model::Tools::Snp::ConvertHapMapGenotypeToGoldSNP;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Bio::DB::Fasta;

class Genome::Model::Tools::Snp::Evaluation {
    is => 'Command',
    has => [
    genotype_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "Input file of Hapmap Genotype data for a single individual",
    },
    output_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Output file name for converted Genotype Data. Will be in a format that mimics a Gold SNP file",
    },        
    exclude_y =>
    {
        type => 'Boolean',
        is_optional => 1,
        doc => "Don't consider SNPs present on the Y chromosome",
        default => 0,
    },        
    REFDIR =>
    {
        #This is the path to the reference sequence used for aligning the model
        type => 'String',
        is_optional => 0,
        default => "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c",
    },        
    refdb =>
    {
        type => 'Reference',
        is_optional => 1;
    },
    ]
};


sub execute {
    my $self=shift;

    #Check on the file names
    unless(-f $self->genotype_file) {
        $self->error_message("Hapmap genotype file is not a file: " . $self->snp_file);
        return;
    }

    #Check and open filehandles
    my $genotype_fh=IO::File->new($self->genotype_file);
    unless($genotype_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->genotype_file );
        return;
    }

    my $output_fh=IO::File->new($self->output_file,"w");
    unless($output_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->output_file );
        return;
    }

    $self->refdb = Bio::DB::Fasta->new($self->REFDIR);
    
    #read in header
    $output_dh->getline;
    while(my $line = $output_dh->getline) {
        chomp $line;
        $self->convert($line);
    }

    return 1;
}

    


1;

sub help_detail {
    return "This module take a Hapmap Genotype file for a single patient and converts it to Gold SNP style format for use with established tools"
}

#Create hashes of gold SNPs

sub convert {
    my ($self,$line) = @_;
    my $refdb = $self->refdb;
    my ($snp_id,$dbsnp_alleles,$chr,$pos,$strand,$genotype) = split /\s*/, $line; 

    #adjust chromosome
    $chr ~= s/chr//i;

    my @alleles = split //, $genotype;

    my $ref_allele = uc($refdb->seq($chr,$pos));

    unless(grep {uc($_) eq $ref_allele} @alleles) {
        print "Didn't find reference for $chr $pos where ref was $ref_allele and strand was $strand\n";
    }

    return (\%heterozygous_snp_at,\%reference_snp_at);
}

