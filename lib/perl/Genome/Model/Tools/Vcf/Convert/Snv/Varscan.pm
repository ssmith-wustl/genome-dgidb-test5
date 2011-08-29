package Genome::Model::Tools::Vcf::Convert::Snv::Varscan;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Snv::Varscan {
    is =>  'Genome::Model::Tools::Vcf::Convert::Base' ,
};


sub help_brief {
    "tool to convert varscan output to vcf"
}

sub help_synopsis {
    return "no help specified";
}

sub help_detail { 
    return "foobar";
}


sub parse_line { 
    my $self=shift;
    my $line = shift;

    my @fields = split "\t", $line;
    my $chr = $fields[0];
    my $pos = $fields[1];

    my $ref_allele = $fields[2];
    $ref_allele =~ s/[^ACGTN\-]/N/g;
    my $var_allele_iub = $fields[3];
    #convert iub to only variant alleles
    my @var_alleles =   Genome::Info::IUB->variant_alleles_for_iub($ref_allele, $var_allele_iub);
    my @all_alleles = Genome::Info::IUB->iub_to_alleles($var_allele_iub);
    my $GT = $self->generate_gt($ref_allele, \@var_alleles, \@all_alleles);
    if(!$GT) {
        $self->error_message("unable to convert $line into GT field");
        return 0;
    }
    my $alt_alleles = join(",", @var_alleles);
    #no genotype quality, hardcode .
    my $GQ='.'; ##TODO: figure out if this is a good idea
    #total depth
    my $DP= $fields[4]+$fields[5];
    #avg base quality
    my $BQ = $fields[10];
    #avg mapping quality
    my $MQ = $fields[13];
    #allele_depth
    my $AD = $fields[5];
    #
    my $FA = $fields[6];
    $FA =~ s/\%//;
    $FA /= 100;
    my $VAQ;
    if($fields[11]==0) { #TODO: ask miller wtf this is doing then rename this variable
        $VAQ = 99;
    } else {
        $VAQ = sprintf "%.2f", -10*log($fields[11])/log(10);;
    }


    ##placeholder/dummy, some will be corrected by downstream tool
    my $dbsnp_id = ".";
    my $qual = ".";
    my $filter = "PASS";
    my $info = ".";
    ##need SS check in here for somatic status to come out properly..
    my $format = "GT:GQ:DP:BQ:MQ:AD:FA:VAQ";
    my $sample_string =join (":", ($GT, $GQ, $DP, $BQ, $MQ, $AD, $FA, $VAQ));
    my $vcf_line = join("\t", $chr, $pos, $dbsnp_id, $ref_allele, $alt_alleles, $qual, $filter, $info, $format, $sample_string);
    return $vcf_line;
}


