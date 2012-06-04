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
        doc => 'specify \'build36\' or \'build37\' to describe the input MAF',
        default => 'build36',
    },
    check_transcript_position => {
        is => 'Boolean',
        doc => 'If set (the default option), all sites near the ends of a transcript will be excluded from the analysis if they are not in a functional domain and are not a splice site.',
        default => 1,
    },
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
    This pipeline-like tool is intended to be used to take a germline MAF file and apply any relevant filters related to germline anlaysis to the variants contained within. The focus for some filters is on truncation events, and then genes which still appear to be relevant (which contain truncations) after elimination of non-essential truncation events are used as the filter to determine the relevancy of the non-truncation events.

    The expected workflow prior to using this tool is 1) create a model-group of relevant somatic-variation models 2) run 'gmt capture somatic-variation-group' on the model-group (which will gather germline variants and run the false-positive-filter on germline SNVs, and hopefully soon this tool will run the homopolymer filter on germline indels) 3) run the homopolymer filter on all gathered germline indels 4) create a MAF containing all germline SNVs and indels. 

EOS
}

sub execute {

    # process input arguments
    my $self = shift;

    $DB::single = 1;

    my $maf_build = $self->maf_genome_build;
    my @genes_to_exclude = split ",",$self->genes_to_exclude;
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
    if ($maf_build =~ /build36/i) { $tr_length_file = '/gscmnt/gc6111/info/medseq/transcript_lengths/54_36p_v4.transcript_lengths'; }
    elsif ($maf_build =~ /build37/i) { $tr_length_file = '/gscmnt/gc6111/info/medseq/transcript_lengths/58_37c_v2.transcript_lengths'; }
    else { $self->error_message("Please enter either 'build36' or 'build37' to describe the genome build of the MAF."); return; }
    my $tr_length_fh = new IO::File $tr_length_file,"r";
    while (my $line = $tr_length_fh->getline) {
        chomp $line;
        next if ($line =~ /transcript_name/);
        my ($tr,$length,$ninety_five_perc) = split /\t/,$line;
        $tr_95perc_of_length{$tr} = $ninety_five_perc;
    }
    $tr_length_fh->close;

    # create temporary file locations to separately store truncation events and non-truncation events # my $temp_dir = Genome::Sys->create_temp_directory();
    my $trunc_file = Genome::Sys->create_temp_file_path(); my $trunc_fh = new IO::File $trunc_file,"w";
    my $non_trunc_file = Genome::Sys->create_temp_file_path(); my $non_trunc_fh = new IO::File $non_trunc_file,"w";
    my @fhs = ($trunc_fh,$non_trunc_fh);
    my $fhs_ref = \@fhs;

    # read through MAF to easily eliminate some sites and categorize the rest
    my $maf_fh = new IO::File $maf,"r";
    unless ($maf_fh) {
        $self->error_message("Could not open filehandle for $maf.");
        return;
    }

    # parse MAF header
    my %maf_columns;
    my $maf_columns_ref = \%maf_columns;
    $maf_columns_ref = $self->parse_maf_header($maf_fh,$maf_columns_ref,$fhs_ref);

    # parse MAF variants and remove / categorize variants as necessary
    while (my $line = $maf_fh->getline) {

        # separate fields
        chomp $line;
        my @fields = split /\t/,$line;

        # read fields
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

        # remove variants near the end of the transcript (>95% tr length) if domain == NULL and type != splice site
        if ($self->check_transcript_position) {
            if ($domain eq 'NULL' && $variant_class ne 'Splice_Site') {
                (my $c_pos_value = $c_position) =~ /[\._](\d+)$/;
                if (exists $tr_95perc_of_length{$transcript}) {
                    next if ($c_pos_value > $tr_95perc_of_length{$transcript});
                }
                else {
                    $self->status_message("Could not check variant in gene $gene on transcript $transcript for extremely 3' position.");
                }
            }
        }

        # segregate truncations and print to files
        if ($variant_class =~ /^Splice_Site|^Frame_Shift|^Nonsense|^Nonstop/i) {
            print $trunc_fh "$line\n"; next;
        }
        else {
            print $non_trunc_fh "$line\n"; next;
        }

    } # end of reading through MAF

    # close open filehandles
    for my $fh (@fhs) { $fh->close; }

    # if necessary, liftover files to build 37
    my $build37_trunc_file;

    if ($maf_build =~ /build36/i) {

        #create file location for lifted file
        $build37_trunc_file = Genome::Sys->create_temp_file_path();

        # check to make sure necessary columns are there, coordinate-wise
        unless (exists $maf_columns{'Chromosome'} and exists $maf_columns{'Start_position'} and exists $maf_columns{'End_position'}) {
            $self->error_message("MAF does not seem to contain appropriate headers regarding variant coordinates. Aborting.");
            return;
        }

        # determine columns to lift from MAF coordinates and possibly annotation coordinates (converting to 1-based)
        my $sets = join("_",$maf_columns{'Chromosome'}+1,$maf_columns{'Start_position'}+1,$maf_columns{'End_position'}+1);
        if (exists $maf_columns{'chromosome_name'} and exists $maf_columns{'start'} and exists $maf_columns{'stop'}) {
            my $annotation_set = join("_",$maf_columns{'chromosome_name'}+1,$maf_columns{'start'}+1,$maf_columns{'stop'}+1);
            $sets = join(",",$sets,$annotation_set);
        }

        # use lift-over-multiple-columns tool #FIXME MOVE TO TOP NOT FINISHED
        my $lift_cmd = Genome::Model::Tools::LiftOverMultipleColumns->create(
            source_file      => $trunc_file,
            destination_file => $build37_trunc_file,
            columns_to_lift  => $sets,
            header_id_string => "Chromosome| "#FIXME
        );
    }
    else { $build37_trunc_file = $trunc_file; }



    #using dbsnp 135, append frequency of variant in the population. Dan has a script to merge maf and dbsnp freq (with zeros when variant not present)

    #using 1000 genomes files (also build 37), append frequencies of all three populations for the site.
    #remove site if the total freq >= 1% (this could be done based on population structure)

    #append NHLBI frequencies for future use (SNPs only, put NA for indels)


    ##########################################################
    # VEP (OPTIONAL) (NEEDS build 37)                        #
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

sub parse_maf_header {

    my $self = shift(@_);
    my ($maf_fh,$maf_columns_ref,$output_file_handles_ref) = @_;
    my $maf_header = $maf_fh->getline;
    while ($maf_header =~ /^#/) { 
        for my $fh (@{$output_file_handles_ref}) { $fh->print($maf_header); }
        $maf_header = $maf_fh->getline;
    }
    if ($maf_header =~ /Chromosome/) {
        chomp $maf_header;
        # header exists; print to each output filehandle and record column identities
        for my $fh (@{$output_file_handles_ref}) { $fh->print($maf_header); }
        my @header_fields = split /\t/,$maf_header;
        for (my $col_counter = 0; $col_counter <= $#header_fields; $col_counter++) {
            $maf_columns_ref->{$header_fields[$col_counter]} = $col_counter;
        }
    }
    else {
        $self->error_message("MAF does not seem to contain a header.");
        return;
    }
}



1;
