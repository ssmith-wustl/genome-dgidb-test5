package Genome::Model::Tools::Germline::Filtering;

use warnings;
use strict;
use IO::File;
use Genome;

class Genome::Model::Tools::Germline::Filtering {
    is => 'Command',
    has_input => [
    maf_file => {
    },
    ],
    has_optional_input => [
    ],
    has_calculated_optional => [
    ],
    doc => 'A germline variant detection pipeline starting from a germline MAF',
};

sub help_synopsis {
    return <<EOS
    This tool does x, y, and z. An example usage is:

    gmt germline filtering --x a --y b --z c

EOS
}

sub help_detail {
    return <<EOS
    Write detailed help here...

EOS
}

sub execute {
    my $self = shift;

    #read maf and make separate temp file for both indels and snvs
    

    #INDELS: run homopolymer filter

    #####################################
    # Removals, etc.                    #
    #####################################

    #combine snvs and indels (or run the following tools on both separately)
    

    #remove sites from XM_ transcripts
    #--AND--
    #screen the transcript in the annotation of each site by looking in the file /gscmnt/gc6132/info/medseq/ensembl/downloads/human/66/Homo_sapiens.GRCh37.66.gtf.gz keeping only sites from transcripts which have "protein coding" in col 2 of that file
    #print STDERR msg for transcripts not in file


    #exlude sites that have transcript errors (keep sites with "no errors")
    

    #exclude sites from genes with improper reference sequence


    #OPTIONAL: exclude sites present on the last 5% of the transcript (c-terminal) - DO NOT USE on splice sites or if there is a functional domain (not NULL)



    #remove sites if c position is c.NULL
    

    #remove all LOC, ORF, and Olfactory receptor (OR*) genes


    ############################################################
    # append population frequencies                            #
    ############################################################

    #LIFTOVER TO BUILD 37 if sites are on BUILD 36 HERE

    #dbsnp 135 (remove site if freq > 1%) (MAYBE - ASK MIKE)
    
    #1000 genomes (remove site if freq > 1%)

    #NHLBI frequencies (SNPs only, put NA for indels)

    #LIFTOVER BACK to build 36 if necessary

    ##########################################################
    # VEP (OPTIONAL)                                         #
    ##########################################################

    # convert to format for running VEP

    # run VEP



    return 1;
};

1;
