package Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Vcf::Convert::Indel::PindelSingleGenome {
    is =>  'Genome::Model::Tools::Vcf::Convert::Base' ,
    doc => 'Generate a VCF file from varscan output',
    has => [
        _refseq => {
            is => 'Text',
            calculate_from => ['reference_sequence_input'],
            calculate => q| $reference_sequence_input |,
        },
    ],
};

sub help_synopsis {
    <<'HELP';
    Generate a VCF file from pindel indel output
HELP
}

sub help_detail {
    <<'HELP';
    Parses the input file and creates a VCF containing all the indels.
HELP
}

sub source {
    my $self = shift;
    return "Pindel";
}

sub execute {
    my $self = shift;
    #my $input_fh = $self->_input_fh;

    #FIXME   this is all hardcoded, these need to be filled dynamically
    my $pindel2vcf_path = "/gscmnt/ams1158/info/pindel/pindel2vcf/pindel2vcf";
    my $refseq = $self->_refseq;
    my $rs = $self->reference_sequence_build; 
    my $refseq_name = $rs->name;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $date = $year . "/" . ($mon+1) . "/" . $mday . "-" . $hour . ":" . $min . ":" . $sec;
    my $pindel_raw = $self->input_file;
    my $output = $self->output_file;
    my $cmd  = $pindel2vcf_path . " -p ".$pindel_raw." -r ". $refseq . " -R " . $refseq_name . " -d " . $date . " -v " . $output; 
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    unless($result){
        die $self->error_message("Could not complete pindel2vcf run: ".$result);
    }
    my $bgzip_cmd = "bgzip -c ".$output." > ".$output.".tmp";
    $result = Genome::Sys->shellcmd( cmd => $bgzip_cmd );
    unless($result){
        die $self->error_message("Could not complete bgzip of output: ".$result);
    }
    unlink($output);
    $result = Genome::Sys->copy_file($output.".tmp",$output);
    unless($result){
        die $self->error_message("Could not move tmp zipped output to final output_file location: ".$result);
    }
    unlink($output.".tmp"); 
    return 1;
}

=cut
    while(my $line = $self->get_record($input_fh)) {
        my $output_line = $self->parse_line($line);
        if ($output_line) {
            $self->write_line($output_line);
        }
    }
    return 1;
}
=cut


sub get_record {
    my $self = shift;
    my $input_fh = shift;
    my $line = $input_fh->getline;
    my @event = ();
    if($line =~ m/^#+$/){
        my $call = $input_fh->getline;
        chomp $call;
        push @event, $call;
        my $reference = $input_fh->getline;
        chomp $reference;
        push @event, $reference;
        my @call_fields = split /\s/, $call;
        my $support = $call_fields[15];

        unless(defined($support)){
            print "No support. Call was:   ".$call."\n";
            die;
        }

        for (1..$support){
            $line = $input_fh->getline;
            chomp $line;
            push @event, $line;
        }
    } else {
        die $self->error_message("Reading pindel data out of sync. Each record starts with ####.., started with a line that did not begin with #'s");
    }

    return \@event;
}

sub parse_line { 
    my $self=shift;
    my $line = shift;
    my @event = @{$line};
    my $call = $event[0];
    my $reference = $event[1];
    my $read = $event[2];
    my ($ref,$var,$leading_base) = $self->parse($call,$reference,$read);

    my @fields = split /\s+/, $call;

    my $chr = $fields[7];
    my $pos = $fields[9];

    my $dbsnp_id = ".";
    #my $indel_string = $var; #last field on varscan call should be: +ACT or -GA deletion/insertion reporting style
    my $alt_alleles = $var;
    my $ref_allele = $ref;

=cut
    if($indel_string =~ m/\+/)  { #insertion
        $alt_alleles = $leading_base . substr($indel_string, 1);
        $ref_allele = $leading_base;
    }
    elsif($indel_string =~m/-/) { #deletion
        #we should switch ref and alt (compared to insertions) to show that those bases are going away
        $ref_allele = $leading_base . substr($indel_string,1);
        $alt_alleles = $leading_base;
    }
    else {
        die $self->error_message("line does not *appear* to contain a +/- char in final field, don't know what to do: $line");
    }
=cut

    #TODO this is turned off for now because it interferes with applying filters (bed coordinates will be different once left shifted)
    # ($chr, $pos, $ref_allele, $alt_alleles) = $self->normalize_indel_location($chr, $pos, $ref_allele, $alt_alleles);
    my $genotype_call = $fields[3];
    my $GT;
    if($genotype_call =~ m/\*/) { #my belief is that varscan only calls het or hom. so if we see match an asterisk, we know its het. 
        $GT="0/1";
    }else {
        $GT="1/1";
    }
    my $DP=$fields[4]+$fields[5];  #ref allele supporting reads + var allele supporting reads
    my $MQ= '.'; #$fields[13]; # ref allele supporitng read map qual
    my $AD = $fields[5];
    my $FA = sprintf("%0.3f",$fields[5]/$DP);
    my $FET = sprintf("%e", $fields[11]);


    ##fill in defaults
    my $BQ=".";
    my $GQ=".";
    my $VAQ = ".";
    my $filter = "PASS";
    my $info = ".";
    my $qual = ".";

    ##need SS check in here for somatic status to come out properly..
    my $format = "GT:GQ:DP:BQ:MQ:AD:FA:VAQ:FET";
    my $sample_string =join (":", ($GT, $GQ, $DP, $BQ, $MQ, $AD, $FA, $VAQ, $FET));
    my $vcf_line = join("\t", $chr, $pos, $dbsnp_id, $ref_allele, $alt_alleles, $qual, $filter, $info, $format, $sample_string);
    return $vcf_line;
}

sub get_format_meta {
    my $self = shift;

    # Get all of the base FORMAT lines
    my @tags = $self->SUPER::get_format_meta; 

    my $fet = {MetaType => "FORMAT", ID => "FET", Number => 1, Type => "String", Description => "P-value from Fisher's Exact Test"};

    return (@tags, $fet);
}


sub parse {
    my $self=shift;
    my ($call, $reference, $first_read) = @_;
    my $refseq = $self->_refseq;
    my @call_fields = split /\s+/, $call;
    my $type = $call_fields[1];
    my $size = $call_fields[2];
    my ($chr, $start, $stop);
    $chr = $call_fields[7];
    $start = $call_fields[9];
    $stop = $call_fields[10];
    my $support = $call_fields[15];
    my $leading_base;
    my ($ref, $var);
    if($type =~ m/D/) {
        $var =0;
        ###Make pindels coordinates(which seem to be last undeleted base and first undeleted base) 
        ###conform to our annotators requirements
        $stop = $stop -1;
        ###also deletions which don't contain their full sequence should be dumped to separate file
        my $allele_string;
        my $start_for_faidx = $start+1;
        my $sam_default = Genome::Model::Tools::Sam->path_for_samtools_version;
        my $faidx_cmd = "$sam_default faidx " . $self->_refseq . " $chr:$start_for_faidx-$stop";
        my @faidx_return= `$faidx_cmd`;
        shift(@faidx_return);
        chomp @faidx_return;
        $allele_string = join("",@faidx_return);

        $ref = $allele_string;
    }
    elsif($type =~ m/I/) {
        #misunderstanding of bed format
        #0 based numbers teh gaps so an insertion of any number of bases between base 10 and 11 in 1base
        #is 10 10 in bed format
        #$start = $start - 1;
        $ref=0;
        my ($letters_until_space) =   ($reference =~ m/^([ACGTN]+) /);
        my $offset_into_first_read = length($letters_until_space);
        $var = substr($first_read, $offset_into_first_read, $size);
        $stop = $stop - 1;
    }
    if($size >= 100) {
        my $big_fh = $self->_big_output_fh;
        print $big_fh join("\t",($chr,$start,$stop,$size,$support))."\n";
        return undef;
    }
    return ($ref,$var,$leading_base);
}
