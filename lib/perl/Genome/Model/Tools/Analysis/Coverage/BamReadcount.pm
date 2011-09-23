package Genome::Model::Tools::Analysis::Coverage::BamReadcount;

use strict;
use Genome;
use IO::File;
use warnings;


class Genome::Model::Tools::Analysis::Coverage::BamReadcount{
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
	    doc => 'File containing snvs in 1-based, 5-col format (chr, st, sp, var, ref). indels will be skipped and not output',
	},

        output_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'output file suitable for input into clonality plot',
        },

        genome_build => {
            is => 'String',
            is_optional => 1,
	    doc => 'genome build (36 or 37)',
            default => '36',
        },

        min_quality_score => {
            is => 'Integer',
            is_optional => 1,
	    doc => 'minnimum mapping quality of a read',
            default => '1',
        },

        ]
};

sub help_brief {
    "get readcounts. make pretty. output ref, var, vaf"
}

sub help_detail {
    "get readcounts. make pretty"
}



sub execute {
    my $self = shift;
    my $bam_file = $self->bam_file;
    my $snv_file = $self->snv_file;
    my $output_file = $self->output_file;
    my $genome_build = $self->genome_build;
    my $min_quality_score = $self->min_quality_score;


    my $fasta;
    if ($genome_build eq "36") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "NCBI-human-build36");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    }
    elsif ($genome_build eq "37") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "GRCh37-lite-build37");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    } else {
        die "genome build must be 36 or 37";
    }


    #create temp directory for munging
    my $tempdir = Genome::Sys->create_temp_directory();
    unless($tempdir) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }

    
    #now run the readcounting
    my $cmd = "bam-readcount -q $min_quality_score -f $fasta -l $snv_file $bam_file >$tempdir/readcounts";
    my $return = Genome::Sys->shellcmd(
	cmd => "$cmd",
        );
    unless($return) {
	$self->error_message("Failed to execute: Returned $return");
	die $self->error_message;
    }


    my %refHash;
    my %varHash;
    
    #read in all the snvs and hash both the ref and var allele by position
    my $inFh = IO::File->new( $snv_file ) || die "can't open file\n";
    while( my $sline = $inFh->getline )
    {
        chomp($sline);
        my @fields = split("\t",$sline);

        #skip indels
        if (($fields[3] eq "0") || 
            ($fields[3] eq "-") || 
            ($fields[4] eq "0") || 
            ($fields[4] eq "-") || 
            (length($fields[3]) > 1) || 
            (length($fields[4]) > 1)){
            next;
        }

        $refHash{$fields[0] . "|" . $fields[1]} = $fields[3];
        $varHash{$fields[0] . "|" . $fields[1]} = $fields[4]
    }
    

    #convert iub bases to lists
    sub convertIub{
        my ($base) = @_;
        
        #deal with cases like "A/T" or "C/W"
        if ($base =~/\//){
            my @bases=split(/\//,$base);
            my %baseHash;
            foreach my $b (@bases){
                my $res = convertIub($b);
                my @bases2 = split(",",$res);
                foreach my $b2 (@bases2){
                    $baseHash{$b2} = 0;
                }
            }
            return join(",",keys(%baseHash));
        }

        # use a lookup table to return the correct base
        # there's a more efficient way than defining this, 
        # every time, but meh.
        my %iub_codes;
        $iub_codes{"A"}="A";
        $iub_codes{"C"}="C";
        $iub_codes{"G"}="G";
        $iub_codes{"T"}="T";
        $iub_codes{"U"}="T";
        $iub_codes{"M"}="A,C";
        $iub_codes{"R"}="A,G";
        $iub_codes{"W"}="A,T";
        $iub_codes{"S"}="C,G";
        $iub_codes{"Y"}="C,T";
        $iub_codes{"K"}="G,T";
        $iub_codes{"V"}="A,C,G";
        $iub_codes{"H"}="A,C,T";
        $iub_codes{"D"}="A,G,T";
        $iub_codes{"B"}="C,G,T";
        $iub_codes{"N"}="A,C,G,T";

        return $iub_codes{$base}
    }


    sub matchIub{
        my ($allele,$ref,$var) = @_;
        my @variubs = split(",",convertIub($var));
        my @refiubs = split(",",convertIub($ref));
        foreach my $i (@variubs){
            unless (grep {$_ eq $i} @refiubs) {
                if ($allele eq $i){
                    return 1;
                }
            }
        }
        return 0;
    }



    #prep the output file
    open(OUTFILE,">$output_file") || die "can't open $output_file for writing\n";
   

    #read in the bam-readcount file
    my $inFh2 = IO::File->new( "$tempdir/readcounts" ) || die "can't open file\n";
    while( my $line = $inFh2->getline )
    {
        chomp($line);
        my ($chr, $pos, $ref, $depth, @counts) = split("\t",$line);

        my $ref_count = 0;
        my $var_count = 0;
        my $knownRef;
        my $knownVar;
        my $var_freq = 0;
        
        # skip if it's not in our list of snvs
        next unless (exists($refHash{$chr . "|" . $pos}) && exists($varHash{$chr . "|" . $pos}));

        #for each base at that pos
        foreach my $count_stats (@counts) {
            my ($allele, $count, $mq, $bq) = split /:/, $count_stats;
            
            #look up the snv calls at this position
            $knownRef = $refHash{$chr . "|" . $pos};
            $knownVar = $varHash{$chr . "|" . $pos};

            #handle snvs first
            if($knownRef ne "-" && $knownVar ne "-"){
                # assume that the ref call is ACTG, not iub 
                # (assumption looks valid in my files)
                if ($allele eq $knownRef){
                    $ref_count += $count;
                }
                
                # if this base is included in the IUB code for
                # for the variant, (but doesn't match the ref)
                if (matchIub($allele,$knownRef,$knownVar)){
                    $var_count += $count;
                }
                
                if ($depth ne '0') {
                    $var_freq = $var_count/$depth * 100;
                }            

            } else { #is an indel, skip it
                $ref_count = "NA";
                $var_count = "NA";
                $var_freq = "NA";
            }
        }

        print OUTFILE "$chr\t$pos\t$knownRef\t$knownVar\t$ref_count\t$var_count\t";
        if ($var_freq eq "NA"){
            print OUTFILE $var_freq;
        } else {
            print OUTFILE sprintf("%.2f",$var_freq);
        }
        print OUTFILE "\n";
    }
    close(OUTFILE)
}
