package Genome::Model::Tools::Assembly::CreateSubmissionFiles;

use strict;
use warnings;

use Genome;

use Cwd;
use Bio::SeqIO;
use Sys::Hostname;
use Data::Dumper;
use File::Basename;
use Finishing::Assembly::Factory;
use Finishing::Assembly::ContigTools;

class Genome::Model::Tools::Assembly::CreateSubmissionFiles {
    is => 'Command',
    has => [],
};

sub help_brief {
    'Tools to create pcap-like submission output files'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly create-submission-files ...
EOS
}

sub xhelp_detail {                           
    return <<EOS
Tools to create pcap-like submission files from various assembler output files
EOS
}

sub create_input_from_fastq {
    my ($self, $fastq) = @_;
    unless (-s $fastq) {
	$self->error_message("Unable to read file: $fastq");
	return;
    }
    my $file_name = basename($fastq);
    my $root_name = $file_name;
    ($root_name) = $file_name =~ /(\S+)\.fastq$/ if
	$file_name =~ /\.fastq$/;

    my $fasta_out = $root_name.'.fasta';
    my $qual_out = $root_name.'.fasta.qual';

    my $in = Bio::SeqIO->new(-format => 'fastq', -file => $fastq);
    #CREATE INPUT FASTA AND QUAL FILES
    my $f_out = Bio::SeqIO->new(-format => 'fasta', -file => ">$fasta_out");
    my $q_out = Bio::SeqIO->new(-format => 'qual', -file => ">$qual_out");
    #READS.UNPLACED.FASTA
    my $f_up_out = Bio::SeqIO->new(-format => 'fasta', -file => ">reads.unplaced.fasta");
    #READS.UNPLACED.FOF
    my $r_up_fh = IO::File->new("> reads.unplaced.fof") || die
	"Failed to create file handle for reads.unplaced.fof file";

    while (my $fq = $in->next_seq) {
	#CHECK IF THIS READ HAS BEEN ASSEMBLED
	if (! exists $self->{data}->{reads_assembled}->{$fq->id}) {
	    $f_up_out->write_seq($fq);
	    $r_up_fh->print($fq->id."\n");
	}
	$f_out->write_seq($fq);
	#SUBTRACT 31 FROM QUAL VALUES TO MAKE IT PHRED COMPATIBLE FOR VELVET ASSEMBLIES
	if ($self->assembler eq 'Velvet') {
	    my @new_quals = map {$_ -= 31} @{$fq->qual};
	    $fq->qual(\@new_quals);
	}
      	$q_out->write_seq($fq);
    }

    $r_up_fh->close;

    system ("gzip $fasta_out $qual_out");

    return 1;
}

sub get_ace_obj {
    my ($self, $ace) = @_;
    my $af = Finishing::Assembly::Factory->connect('ace', $ace);
    return $af->get_assembly;
}

sub create_contigs_files {
    #HAVE IT SEND ACE OBJ
    my ($self, $ace_obj) = @_;

    my $f_out = Bio::SeqIO->new(-format => 'fasta', -file => "> contigs.bases");
    my $q_out = Bio::SeqIO->new(-format => 'qual', -file => "> contigs.quals");

    foreach my $contig($ace_obj->contigs->all) {
	my $seq_obj = Bio::Seq->new(-id => $contig->name, -seq => $contig->unpadded_base_string);
	$f_out->write_seq($seq_obj);
	my $qual_obj = Bio::Seq::PrimaryQual->new(-id => $contig->name, -qual => \@{$contig->unpadded_base_qualities});
	$q_out->write_seq($qual_obj);
    }

    return 1;
}

sub create_read_info_files {
    #CREATES readinfo.txt, reads.placed
    my ($self, $ace_obj, $gap_file) = @_;

    my $ri_fh = IO::File->new("> readinfo.txt") || die
	"Failed to create file handle for readinfo.txt file";

    my $rp_fh = IO::File->new("> reads.placed") || die
	"Failed to create file handle for reads.placed file";
    my $gap_lengths;

    unless ($gap_lengths = $self->_get_gap_lengths ($gap_file)) {
	$self->error_message("Failed to get gap_lengths");
	return;
    }

    $self->{data}->{reads_placed} = {};

    foreach my $contig ($ace_obj->contigs->all) {
	#FIGURE OUT CONTIG POSITION IN SUPERCONTIG
	my ($ctg, $sctg_num, $ctg_num) = $contig->name =~ /(contig)(\d+)\.(\d+)$/i;
	my $sctg_name = $ctg.$sctg_num;
	my $ctg_sctg_position = 0;
	for (my $i = 1; $i < $ctg_num; $i++) {
	    my $tmp_ctg_name = $ctg.$sctg_num.'.'.$i;
	    if (my $tmp_ctg_obj = $ace_obj->get_contig($tmp_ctg_name)) {
		$ctg_sctg_position += $tmp_ctg_obj->length;
		#NEED AN ERROR CHECK HERE
		unless (exists $gap_lengths->{$tmp_ctg_name}) {
		    $self->error_message("Gap size does not exist for $tmp_ctg_name");
		    return;
		}
		$ctg_sctg_position += $gap_lengths->{$tmp_ctg_name};
	    }
	}

	foreach my $read ($contig->assembled_reads->all) {
	    $self->{data}->{reads_assembled}->{$read->name} = 1;
	    my $c_or_u = ($read->complemented) ? 'C' : 'U';
	    #EXAMPLE: FU655KU01A00D7 Contig15.60 U 6616 133
	    $ri_fh->print( $read->name.' '.$contig->name.' '.$c_or_u.' '.$read->start.' '.$read->length."\n" );
	    #EXAMPLE: * FU655KU01A0622_left 1 43 1 Contig7.42 Supercontig7 7550 457046
	    $rp_fh->print('* '. $read->name.' 1 '.$read->length.' '.$read->complemented.' '.$contig->name.' Supercontig'.$sctg_num.' '.$read->start.' '.$ctg_sctg_position."\n");
	}
    }

    $ri_fh->close;
    $rp_fh->close;
    return 1;
}

sub _get_gap_lengths {
    my ($self, $gap_file) = @_;
    my $gap_lengths = {};
    unless (-s $gap_file) {
	$self->error_message("Failed to find $gap_file");
	return;
    }
    my $fh = IO::File->new("< $gap_file") || die
	"Failed to create file handle for $gap_file";
    while (my $line = $fh->getline) {
	my @ar = split (/\s+/, $line);
	unless (scalar @ar == 2) {
	    $self->error_message("Incorrect line format for gap file in line: $line");
	    return;
	}
	#HASH->{CONTIG_NAME} = GAP_LENGTH
	$gap_lengths->{$ar[0]} = $ar[1];
    }
    $fh->close;
    return $gap_lengths;
}

sub change_to_assembly_dir {
    my $self = shift;
    my $dir = ($self->directory) ? $self->directory : cwd();
    $dir =~ s/\/$//;
    unless ($dir =~ /edit_dir$/) {
	$dir .= '/edit_dir';
    }
    unless (-d $dir) {
	$self->error_message("Failed to locat directory: $dir");
	return;
    }
    unless (chdir $dir) {
	$self->error_message("Failed to change to dir: $dir");
	return;
    }

#   print $dir."\n";

    return 1;
}

sub create_supercontigs_agp_file {
    my ($self, $gap_file) = @_;

    my $ec = system ("create_agp_fa.pl -input contigs.bases -gapfile $gap_file -agp supercontigs.agp");
    if ($ec) {
	$self->error_message("Failed to execute create_agp_fa.pl");
	return;
    }
    return 1;
}

sub create_supercontigs_fa_file {
    my $self = shift;
    my $ec = system("xdformat -n -I contigs.bases");
    if ($ec) {
	$self->error_message("xdformat contigs.bases failed");
	return;
    }
    $ec = system ("create_fa_file_from_agp.pl supercontigs.agp supercontigs.fasta contigs.bases");
    if ($ec) {
	$self->error_message("create_fa_file_from_agp.pl failed");
	return;
    }
    unlink 'contigs.bases.xni', 'contigs.bases.xns', 'contigs.bases.xnd', 'contigs.bases.xnt';
    return 1;
}

sub run_core_gene_survey_manually {
    my ($self, $survey_option) = @_;
    return 1;
}

sub run_core_gene_survey {
    my ($self, $survey_option) = @_;
    my $host = hostname();
    if ($host =~ /linusit/) {
	$self->error_message("Can not run core gene survey from linusit machine");
	return 1;
    }
    my $ec = system("run_coregene_cov_pid_script contigs.bases 30 0.3 -assembly $survey_option");
    if ($ec) {
	$self->error_message("Core gene survey failed");
	return;
    }
    return 1;
}

sub assembler {
    my $self = shift;
    my ($assembler) = ref($self) =~ /(\w+)$/;
    return $assembler;
}

1;

