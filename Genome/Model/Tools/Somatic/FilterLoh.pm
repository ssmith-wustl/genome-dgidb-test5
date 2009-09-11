package Genome::Model::Tools::Somatic::FilterLoh;

use warnings;
use strict;

use Genome;
use Carp;
use IO::File;
use Genome::Info::IUB;

class Genome::Model::Tools::Somatic::FilterLoh{
    is => 'Command',
    has => [
        tumor_snp_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'File of tumor SNPs in maq-like format',
        },
        normal_snp_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of normal SNPs in maq-like format',
        },
    ],
};

sub help_brief {
    "Separate LOH calls from non-LOH calls",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools somatic filter-loh...    
EOS
}

sub help_detail {                           
    return <<EOS 
This filters out SNVs that are likely to be the result of Loss of Heterozygosity (LOH) events. The Somatic Pipeline will pass these through on its own as they are tumor variants that differ from the normal. This script defines a variant as LOH if it is homozygous, there is a heterozygous SNP at the same position in the normal and the tumor allele is one of the two alleles in the normal.  
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    unless(-f $self->tumor_snp_file) {
        $self->error_message($self->tumor_snp_file . " is not a file");
        return;
    }

    unless(-f $self->normal_snp_file) {
        $self->error_message($self->normal_snp_file . " is not a file");
        return;
    }

    #MAKE A HASH OF NORMAL SNPS!!!!!!!!!!!!!
    #Assuming that we will generally be doing this on small enough files (I hope). I suck.

    my $normal_snp_fh = IO::File->new($self->normal_snp_file,"r");
    unless($normal_snp_fh) {
        $self->error_message("Unable to open " . $self->normal_snp_file);
        return;
    }

    my %normal_variants;

    while(my $line = $normal_snp_fh->getline) {
        chomp $line;
        my ($chr, $pos, $ref, $var_iub) = split /\t/, $line;
        next if($var_iub =~ /[ACTG]/);
        my @alleles = Genome::Info::IUB->iub_to_alleles($var_iub);
        $normal_variants{$chr}{$pos} = join '',@alleles;
    }

    $normal_snp_fh->close;
    
    my $tumor_snp_fh = IO::File->new($self->tumor_snp_file,"r");
    unless($tumor_snp_fh) {
        $self->error_message("Unable to open " . $self->tumor_snp_file);
        return;
    }

    while(my $line = $tumor_snp_fh->getline) {
        chomp $line;

        my ($chr, $pos, $ref, $var_iub) = split /\t/, $line;
        if($var_iub =~ /[ACTG]/ && exists($normal_variants{$chr}{$pos})) {
            #only consider homozygous sites
            if(index($normal_variants{$chr}{$pos},$var_iub) > -1) {
                #then they share this allele and it is LOH
            }
            else {
                print $line, "\n";
            }
        }
        else {
            print $line, "\n";
        }
    }

    $tumor_snp_fh->close;

    return 1;
}

