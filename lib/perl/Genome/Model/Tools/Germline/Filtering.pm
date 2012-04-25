package Genome::Model::Tools::Germline::Filtering;

use warnings;
use strict;
use IO::File;
use Genome;

class Genome::Model::Tools::Germline::Filtering {
    is => 'Command',
    has_input => [
    maf_file => {
        is => 'String',
        doc => 'Germline MAF to be filtered',
    },
    ],
    has_optional_input => [
    genes_to_exclude => {
        is => 'String',
        doc => 'Comma-delimited list of genes to exclude which have bad reference sequence, or any other reason for neglect',
        default => 'PDE4DIP,CDC27,MUC4,DUX4',
    },
    maf_genome_build => {
        is => 'String',
        doc => 'specify \'build36\' or \'build37\' to describe the input MAF';
        default => 'build36',
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

    # process input arguments
    my $self = shift;
    my $build = $self->maf_genome_build;
    my @genes_to_exclude = split ",",$self->genes_to_exlude;
    my $maf = $self->maf_file;
    unless (-s $maf) {
        $self->error_message("MAF does not exist or has zero size.");
        return;
    }

    # load ensembl file with gene biotypes (source: ftp://ftp.ensembl.org/pub/release-66/gtf/homo_sapiens/Homo_sapiens.GRCh37.66.gtf.gz)
    my %protein_coding_genes;
    my $ensembl_66_gtf_file = "/gscmnt/gc6132/info/medseq/ensembl/downloads/human/66/Homo_sapiens.GRCh37.66.gtf.gz.gene_type_and_name.tsv";
    my $ensembl_66_gtf_fh = new IO::File $ensembl_66_gtf_file,"r";
    while (my $line = $ensembl_66_gtf_fh->getline) {
        chomp $line;
        my ($biotype,$gene) = split /\t/,$line;
        if ($biotype =~ /protein_coding/i && !exists $protein_coding_genes{$gene}) {
            $protein_coding_genes{$gene}++;
        }
    }
    $ensembl_66_gtf_fh->close;

    # load transcript lengths based on input genome build
    my %tr_95perc_of_length;
    my $tr_length_file;
    if ($build =~ /build36/i) { $tr_length_file = 'file??'; }
    elsif ($build =~ /build37/i) { $tr_length_file = 'file??'; }
    else { $self->error_message("Please enter either 'build36' or 'build37' to describe the genome build of the MAF."); return; }
    my $tr_length_fh = new IO::File $tr_length_file,"r";
    while (my $line = $tr_length_fh->getline) {
        chomp $line;
        my ($tr,$length,$ninety_five_perc) = split /\t/,$line;
        $tr_95perc_of_length{$tr} = $ninety_five_perc;
    }
    $tr_length_fh->close;

    # create temporary file locations to separately store truncation SNVs, truncation indels, and non-truncation events
    #my $temp_dir = Genome::Sys->create_temp_directory();
    my $trunc_snv_file = Genome::Sys->create_temp_file_path(); my $trunc_snv_fh = new IO::File $trunc_snv_file,"w";
    my $trunc_indel_file = Genome::Sys->create_temp_file_path(); my $trunc_indel_fh = new IO::File $trunc_indel_file,"w";
    my $non_trunc_file = Genome::Sys->create_temp_file_path(); my $non_trunc_fh = new IO::File $non_trunc_file,"w";
    my @fhs = ($trunc_snv_fh,$trunc_indel_fh,$non_trunc_fh);

    # read through MAF to easily eliminate some sites and categorize the rest
    my $maf_fh = new IO::File $maf,"r";
    unless ($maf_fh) {
        $self->error_message("Could not open filehandle for $maf.");
        return;
    }

    # parse MAF header
    my $maf_header = $maf_fh->getline;
    while ($maf_header =~ /^#/) { 
        for my $fh (@fhs) { $fh->print($maf_header); }
        $maf_header = $maf_fh->getline;
    }
    my %maf_columns;
    if ($maf_header =~ /Chromosome/) {
        chomp $maf_header;
        # header exists; print to each file and record column identities
        for my $fh (@fhs) { $fh->print($maf_header); }
        my @header_fields = split /\t/,$maf_header;
        for (my $col_counter = 0; $col_counter <= $#header_fields; $col_counter++) {
            $maf_columns{$header_fields[$col_counter]} = $col_counter;
        }
    }
    else {
        $self->error_message("MAF does not seem to contain a header.");
        return;
    }

    # parse MAF variants and remove / categorize variants as necessary
    while (my $line = $maf_fh->getline) {
        chomp $line;
        my @fields = split /\t/,$line;
        my $gene = $fields[$maf_columns{'Hugo_Symbol'}];
        my $variant_class = $fields[$maf_columns{'Variant_Classification'}];
        my $variant_type = $fields[$maf_columns{'Variant_Type'}];
        my $transcript = $fields[$maf_columns{'transcript_name'}];
        my $transcript_errors = $fields[$maf_columns{'transcript_error'}];
        my $c_position = $fields[$maf_columns{'c_position'}];
        my $domain = $fields[$maf_columns{'domain'}];

        # remove all self->genes_to_exclude
        next if (scalar grep { /^$gene$/ } @genes_to_exclude);

        # remove all LOC, ENSG, ORF, and Olfactory receptors (OR*)
        next if ($gene =~ /^LOC|^ENSG|^OR|orf/i);

        # remove genes which are not protein-coding
        next unless ($protein_coding_genes{$gene});

        # remove sites with bad transcripts
        next unless ($transcript_errors =~ /no_errors/i);

        # remove non-coding RNA sites
        next if ($c_position =~ /^c\.NULL|^c\.-|^c\.\*/);

        #FIXME MAKE THIS OPTIONAL
        # remove variants near the end of the transcript (>95% tr length) if domain == NULL and type != splice site
        if ($domain eq 'NULL' && $variant_class ne 'Splice_Site') {
            my ($c_pos_value = $c_position) =~ /[\._](\d+)$/;
            next if ($c_pos_value > $tr_95perc_of_length{$transcript});
        }









    #split file into snp and indel

    

    #INDELS: run homopolymer filter

    #####################################
    # Removals, etc.                    #
    #####################################

    #combine snvs and indels (or run the following tools on both separately)

    #separate sites which are not truncation events (truncation = ^splice_site, ^frameshift, nonsense, nonstop)
    #proceed with truncation events only

    #OPTIONAL: exclude sites present on the last 5% of the transcript (c-terminal) - DO NOT USE on splice sites or if functional domain is not NULL
    #to accomplish this - used script modified from bderickson's transcript iteration and found length of transcript, and 95% mark, then compared this to the c_position in the MAF




    ############################################################
    # append population frequencies                            #
    ############################################################

    #LIFTOVER TO BUILD 37 if sites are on BUILD 36 HERE

    #using dbsnp 135, append frequency of variant in the population. Dan has a script to merge maf and dbsnp freq (with zeros when variant not present)
    
    #using 1000 genomes files, append frequencies of all three populations for the site.
    #remove site if the total freq > 1% (this could be done based on population structure)

    #append NHLBI frequencies for future use (SNPs only, put NA for indels)


    ##########################################################
    # VEP (OPTIONAL)                                         #
    ##########################################################

    # convert to format for running VEP

    # run VEP

    # LIFTOVER BACK to build 36 if necessary

    ################################
    # print output                 #
    ################################
    
    # print truncation events to a file

    # limit missense file to only genes that are left in truncation file

    # print non-truncation events to a separate file
    


    return 1;
};

1;
