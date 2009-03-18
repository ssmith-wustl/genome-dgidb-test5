package Genome::Model::Tools::Assembly::Repair::AutoJoin;

use strict;
use warnings;

use Genome;
use IO::File;
use Data::Dumper;
use Sort::Naturally;

class Genome::Model::Tools::Assembly::Repair::AutoJoin {
    is => 'Command',
    has => [],
};

sub help_brief {
    'Tools to run autojoins'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly repair autojoins
EOS
}

sub clean_up_merged_ace
{
    my ($self, $merged_ace) = @_;

    #NEED TO FIX THE DS LINE HERE TO MAKE IT WORK FOR 454 DATA
    my $ds_fixed_ace = $self->_add_version_to_DS_line ($merged_ace);

    #REMOVE AUTOJOIN PHD FILE
    unlink '../phdball_dir/autoJoinPhdBall';

    #NEED TO APPEND ACE FILE WITH WA TAGS TO MAKE TRACES VIEWABLE
    my $done = $self->_add_WA_tags_to_ace ($ds_fixed_ace);

    #REMOVE SOME INTERMEDIATE ACE FILES
    unlink $merged_ace;

    return 1;
}

sub _add_version_to_DS_line
{
    my ($self, $ace) = @_;

    my $ace_out = $ace.'.final';

    my $fh = IO::File->new("< $ace")
	or die "Cannot open file: $ace";

    my $out_fh = IO::File->new (">$ace_out")
	or die "Cannot create file handle: $ace_out";

    while (my $line = $fh->getline)
    {
        if ($line =~ /^DS\s+/)
        {
            chomp $line;
            if ($line =~ /\.sff\:/ and $line =~ /PHD_FILE\:\s+\S+/)
            {
                $line =~ s/^DS /DS VERSION: 1 /;
                $line =~ s/PHD_FILE\:\s+\S+\s+//;
                $line .= ' CHEM: 454';
                $out_fh->print($line."\n");
                next;
            }
            $out_fh->print($line."\n");
            next;
        }
        $out_fh->print($line);
    }
    $fh->close;

    $out_fh->close;

    return $ace_out;
}

sub _add_WA_tags_to_ace
{
    my ($self, $ace) = @_;

    my $fh = IO::File->new(">> $ace")
	or die "Cannot create filehandle for $ace";

    my $ball_dir = '../phdball_dir';

    if (-d $ball_dir)
    {
        my @phdball_files = glob ("$ball_dir/*");
        if (scalar @phdball_files > 0)
        {
            chomp (my $date = `date '+%y%m%d:%H%M%S'`);

            foreach my $ball_file (@phdball_files)
            {
                my $tag = "\nWA{\nphdBall newbler $date\n$ball_file\n}\n";
                $fh->print($tag);
            }
        }
    }
    $fh->close;

    return 1;
}

sub run_cross_match
{
    my ($self, $min_match) = @_;

    my $fasta_file = 'AutoJoin_CM_fasta';

    unless (-s $fasta_file)
    {
	$self->error_message ("cross_match input fasta is missing");
	return;
    }

    my $cm_out_file = 'AutoJoin_CM_fasta_out';

    unlink $cm_out_file if -s $cm_out_file;

    my $ec = system ("cross_match $fasta_file -minmatch $min_match -masklevel 101 > $cm_out_file");

    if ($ec)
    {
	$self->error_message("cross_match failed to run");
	return;
    }

    return 1;
}

sub get_contigs_info_from_ace
{
    my ($self, $ace_obj) = @_;

    my ($contigs, $list) = $self->_get_contigs_info_from_ace ($ace_obj);

    my $contigs_with_scaffolds = $self->_add_scaffolding_info ($contigs, $list);

    return $contigs_with_scaffolds;
}


sub cat_all_phdball_files
{
    my ($self) = @_;

    my $phdball_dir = '../phdball_dir';

    return 1 if ! -d $phdball_dir;

    my $autojoin_ball_name = 'autoJoinPhdBall';

    return 1 if -s $phdball_dir.'/'.$autojoin_ball_name;

    if (-d $phdball_dir)
    {
        my @ball_files = glob ("$phdball_dir/*");

        if (scalar @ball_files > 0)
        {
            foreach my $ball_file (@ball_files)
            {
                my $ec = `cat $ball_file >> $phdball_dir/autoJoinPhdBall`;
                $self->error_message ("Cannot cat $ball_file to autoJoinPhdBall") and
		    return if $ec;
            }
        }
    }

    return 1;
}

sub add_phd_to_ace_DS_line
{
    my ($self, $ace) = @_;

    my $ace_out = $ace.'.DS_line_fixed';
    return unless my $fh = IO::File->new("< $ace");
    return unless my $out_fh = IO::File->new("> $ace_out");

    my $read_name;
    while (my $line = $fh->getline)
    {
        if ($line =~ /^RD\s+/)
        {
            ($read_name) = $line =~ /^RD\s+(\S+)/;
            $out_fh->print($line);
            next;
        }
        if ($line =~ /^DS\s+/)
        {
            if ($line =~ /PHD_FILE\:\s+/)
            {
                $out_fh->print($line);
                next;
            }
            chomp $line;
            $line .= " PHD_FILE: $read_name\n";
            $out_fh->print($line);
            next;
        }
        $out_fh->print($line);
    }

    $fh->close;
    $out_fh->close;
    return $ace_out;
}

sub _get_contigs_info_from_ace
{
    my ($self, $ace_obj) = @_;

    my $contigs = {};

    my $contigs_list = [];

    foreach my $contig ($ace_obj->contigs->all)
    {
	my $reads_count = scalar $contig->assembled_reads->all;
	my $contig_length = $contig->unpadded_length;
	my $name = $contig->name;
	my ($contig_number) = $name =~ /^Contig(\S+)$/i;

	$contigs->{$contig_number}->{name} = $name;
	$contigs->{$contig_number}->{length} = $contig_length;
	$contigs->{$contig_number}->{number_of_reads} = $reads_count;

	push @$contigs_list, $contig_number;
    }

    return $contigs, $contigs_list;
}

sub _add_scaffolding_info
{
    my ($self, $h, $ar) = @_;

    foreach my $ctg (nsort keys %$h)
    {
        next unless $ctg =~ /^\d+\.\d+$/;

        my $scaf = $ctg;
        $scaf =~ s/\.\d+$//;

        #pattern match each contig. to find all contigs
        #in each scaffold

        my (@scafs) = grep (/^$scaf\.\d+$/, @$ar);

        #don't hold scaffold contigs if contig
        #is not part of a scaffold

        next unless scalar @scafs > 1;

        @{$h->{$ctg}->{scaffolds}} = @scafs if @scafs;
    }

    return $h;
}

sub print_contig_ends
{
    my ($self, $ao, $scaf_contigs, $fasta_length) = @_;

    my $fasta_file = 'AutoJoin_CM_fasta';

    unlink $fasta_file if -s $fasta_file;

    my $fh = IO::File->new(">> $fasta_file");

    $self->error_message("Can not create file handle for cross_match fasta") and
	return unless $fh;

    foreach my $contig ($ao->contigs->all)
    {
	my $name = $contig->name;
	my $number = $name;
	$number =~ s/^contig//i;

	#ONLY INCLUDE CONTIGS THAT ARE A PART OF SCAFFOLD
	next unless exists $scaf_contigs->{$number}->{scaffolds};
		
	my ($left_end, $right_end);

	my $fasta = $contig->unpadded_base_string;

	my $length = $contig->unpadded_length;

	$fasta_length = $length if $length < $fasta_length;

	($left_end) = $fasta =~ /^(\w{$fasta_length})/;
	($right_end) = $fasta =~ /(\w{$fasta_length})$/;

	$fh->print(">$name"."-left\n"."$left_end\n");
	$fh->print(">$name"."-right\n"."$right_end\n");
    }

    $fh->close;

    #JUST MAKE SURE SOMETHING PRINTED
    $self->error_message("$fasta_file is blank or missing") and
	return unless -s $fasta_file;

    return 1;
}

1;
