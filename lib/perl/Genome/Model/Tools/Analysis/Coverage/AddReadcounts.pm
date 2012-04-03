package Genome::Model::Tools::Analysis::Coverage::AddReadcounts;
use strict;
use Genome;
use IO::File;
use warnings;


class Genome::Model::Tools::Analysis::Coverage::AddReadcounts{
    is => 'Command',
    has => [
	bam_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'path to the bam file (to get readcounts)',
	},

	snv_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'File containing snvs in annotation format (1-based, first 5-cols =  [chr, st, sp, var, ref]). indels will be skipped and output with NA',
	},

        output_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'output file will be indentical to the input file with readcounts appended as the last two columns',
        },

        genome_build => {
            is => 'String',
            is_optional => 1,
	    doc => 'takes either a string describing the genome build (one of 36, 37lite, mus37, mus37wOSK) or a path to the genome fasta file',
            default => '36',
        },

        min_quality_score => {
            is => 'Integer',
            is_optional => 1,
	    doc => 'minimum mapping quality of a read',
            default => '1',
        },

        chrom => {
            is => 'String',
            is_optional => 1,
	    doc => 'only process this chromosome.  Useful for enormous files',
        },

        min_depth  => {
            is => 'Integer',
            is_optional => 1,
	    doc => 'minimum depth required for a site to be reported',
        },

        max_depth => {
            is => 'Integer',
            is_optional => 1,
	    doc => 'maximum depth allowed for a site to be reported',
        },

        min_vaf => {
            is => 'Integer',
            is_optional => 1,
	    doc => 'minimum variant allele frequency required for a site to be reported (0-100)',
        },

        max_vaf => { 
            is => 'Integer',
            is_optional => 1,
	    doc => 'maximum variant allele frequency allowed for a site to be reported (0-100)',
        },



        ]
};

sub help_brief {
    "get readcounts. make pretty. append to anno file"
}

sub help_detail {
    "get readcounts. make pretty. append to anno file"
}



sub execute {
    my $self = shift;
    my $bam_file = $self->bam_file;
    my $snv_file = $self->snv_file;
    my $output_file = $self->output_file;
    my $genome_build = $self->genome_build;
    my $min_quality_score = $self->min_quality_score;

    my $min_vaf = $self->min_vaf;
    my $max_vaf = $self->max_vaf;
    my $min_depth = $self->min_depth;
    my $max_depth = $self->max_depth;

    my $chrom = $self->chrom;

    my $fasta;
    if ($genome_build eq "36") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "NCBI-human-build36");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    }
    elsif ($genome_build eq "37lite") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "GRCh37-lite-build37");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    }
    elsif ($genome_build eq "mus37") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "NCBI-mouse-build37");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    } elsif ($genome_build eq "mus37wOSK") {
        $fasta = "/gscmnt/sata135/info/medseq/dlarson/iPS_analysis/lentiviral_reference/mousebuild37_plus_lentivirus.fa";
    } elsif (-e $genome_build ) {
        $fasta = $genome_build;
    } else {
        die ("invalid genome build or fasta path: $genome_build\n");
    }


    #create temp directory for munging
    my $tempdir = Genome::Sys->create_temp_directory();
    unless($tempdir) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }

    #set some defaults for undefined parameters
    unless(defined($min_depth)){
        $min_depth = 0;
    }
    unless(defined($max_depth)){
        $max_depth = 999999999;
    }
    unless(defined($min_vaf)){
        $min_vaf = 0;
    }
    unless(defined($max_vaf)){
        $max_vaf = 100;
    }
    unless(defined($genome_build)){
        $genome_build = "36";
    }
    unless(defined($chrom)){
        $chrom = "all";
    }


    #run bam-readcount, stick the files in the tempdir
    my $cmd = Genome::Model::Tools::Analysis::Coverage::BamReadcount->create(
        bam_file => $bam_file,
        output_file =>  "$tempdir/rcfile",
        snv_file => $snv_file,
        genome_build => $genome_build, 
        chrom => $chrom,
        min_depth  => $min_depth,
        max_depth => $max_depth,
        min_vaf => $min_vaf,
        max_vaf => $max_vaf,
        );
    unless ($cmd->execute) {
        die "Bam-readcount failed";
    }

    my %readcounts;
    #read in the bam-readcount file  and hash each count by position
    my $inFh2 = IO::File->new( "$tempdir/rcfile" ) || die "can't open file\n";
    while( my $line = $inFh2->getline )
    {
        chomp($line);
        my ($chr, $pos, $ref, $var, $refcount, $varcount, $vaf,) = split("\t",$line);

	my $key = "$chr:$pos:$ref:$var";

        #for each base at that pos
        $readcounts{$key} = "$refcount:$varcount:$vaf";
    }


    #prep the output file
    open(OUTFILE,">$output_file") || die "can't open $output_file for writing\n";

    #read in all the snvs and hash both the ref and var allele by position
    my $inFh = IO::File->new( $snv_file ) || die "can't open file\n";
    while( my $sline = $inFh->getline )
    {
        chomp($sline);
        my ($chr, $st, $sp, $ref, $var, @rest) = split("\t",$sline);

	my $key = $chr . ":" . $st . ":" . $ref . ":" . $var;

	#get the readcount information at this position
        if(exists($readcounts{$key})){
            my ($rcnt,$vcnt,$vaf) = split(/:/,$readcounts{$key});
            $sline = $sline . "\t$rcnt\t$vcnt\t$vaf\n";
        } elsif (!($ref =~/-|0/) && !($var =~ /-|0/)){ #indel
            $sline = $sline . "\tNA\tNA\tNA\n";
        } else {
            $sline = $sline . "\tNA\tNA\tNA\n";
            print STDERR "$chr:$st:$ref:$var not found in readcounts\n";
        }
        print OUTFILE $sline;
        
    }
    close(OUTFILE);
}
