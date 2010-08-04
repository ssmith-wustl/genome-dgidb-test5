package Genome::Model::Tools::Assembly::ReScaffoldMsiAce;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Assembly::ReScaffoldMsiAce {
    is => 'Command',
    has => [
	acefile => {
	    is => 'Text',
	    doc => 'Assembly ace file',
	},
	scaffold_file => {
	    is => 'Text',
	    doc => 'Assembly scaffold file',
	    is_optional => 1,
	},
	auto_report => {
	    is => 'Boolean',
	    doc => 'Run consed autoreport to get scaffold info',
	    is_optional => 1,
	},
	assembly_directory => {
	    is => 'Text',
	    doc => 'Main assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to re-scaffold msi assemblies';
}

sub help_synopsis {
    return <<EOS
gmt assembly re-scaffold-msi-ace --acefile /gscmnt/111/assembly/edit_dir/newbler.ace --scaffold-file /gscmnt/111/assembly/edit_dir/scaffolds --assembly-directory /gscmnt/111/assembly
gmt assembly re-scaffold-msi-ace --acefile /gscmnt/111/assembly/edit_dir/newbler.ace --assembly-directory /gscmnt/111/assembly --auto-report
EOS
}

sub help_detail {
    return <<EOS
Tool to re-scaffold manually edited ace files.  It will read in
a text file of scaffolding info and re-name contigs to form
pcap style scaffolds, eg, line 8.9-7,15-1.2-1.3 will create the
following scaffolds:

Contig0.1-Contig0.2           (from Contigs8.9 and 7)
Contig1.1-Contig1.2-Contig1.3 (from Contigs15, 1.2 and 1.3)

Tool will also create msi.gap.txt file which is later used
to determine gap sizes between scaffold contigs.  Each gap
will be assigned default, unknown value of 100 bp.

This tool will work with any acefiles from any assembler.
EOS
}

sub execute {
    my $self = shift;

    #TODO - needs refactoring and clean up .. mostly cut and paste from original script rescaffold_msi_ace

    unless (-s $self->acefile) {
	$self->error_message("Can't find file: ".$self->acefile);
	return;
    }

    if ($self->scaffold_file and $self->auto_report) {
	$self->error_message("You can't select to run auto report and supply scaffold file");
	return;
    }

    my $report_file;
    if ($self->auto_report) {
	unless ($report_file = $self->_run_auto_report()) {
	    $self->error_message("Failed to get report file by running auto report");
	    return;
	}
    }
    elsif ($self->scaffold_file) {
	unless (-s $self->scaffold_file) {
	    $self->error_message("Can't find scaffold file: ".$self->scaffold_file);
	    return;
	}
	$report_file = $self->scaffold_file;
    }
    else {
	$self->error_message("You must select to run autoreport or provide a scaffold file");
	return;
    }

    #parse report file .. returns aryref .. could be empty if no scaffolds
    my $scaffolds = $self->_parse_report_file($report_file);

    my $old_scaffolds = $self->_get_old_scaffolds($self->acefile);

    my $new_scaffolds = $self->_create_new_scaffolds($old_scaffolds, $scaffolds);

    my $new_ace = $self->_write_new_ace_file($self->acefile, $new_scaffolds);

    my $final_ace = $self->_update_ds_line($new_ace);

    #TODO - this update ds line is not needed anymore
    unlink $new_ace;

    return 1;
}

sub _run_auto_report {
    my $self = shift;
    $self->status_message("Running consed auto report");
    my $run = GSC::IO::Scaffold::Consed::Run->new($self->acefile);
    unless ($run->execute) {#TODO - make sure this has correct exit code
	$self->error_message("Failed to run consed auto report");
	return;
    }
    my $acefile = $self->acefile;
    my @out_files = `ls -t $acefile*out`;
    return shift @out_files;
}

sub _parse_report_file {
    my ($self, $file) = @_;
    my @scaffolds;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($file) ||
	return;

    foreach my $line ($fh->getlines) {
	next unless ($line =~ /^\d+/ or $line =~ /^E-\d+/);
	chomp $line;
	if ($line =~ /,/) {
	    my @tmp = split (',', $line);
	    foreach (@tmp) {
		push @scaffolds, $_;
	    }
	} else {
	    push @scaffolds, $line;
	}
    }

    $fh->close;

    return \@scaffolds;
}

sub _get_old_scaffolds {
    my ($self, $ace) = @_;
#    my $ace = shift;
    #print "Getting old contigs";
    my $contig_lengths = {};
    my $fh = IO::File->new("<$ace") || die "Can not open ace file: $ace";
    while (my $line = $fh->getline) {
	next unless $line =~ /^CO\s+/;
	my ($contig_name, $length) = $line =~ /^CO\s+(\S+)\s+(\d+)/;
	#print "Incorrect line format in $line\n" and exit (1)
	    #unless $contig_name and $length;
	unless ($contig_name and $length) {
	    $self->error_message("Incorrect line format in $line");
	    return;
	}	
	$contig_name =~ s/contig//i;
	$contig_lengths->{$contig_name} = $length;
    }
    $fh->close;
    return $contig_lengths;
}

sub _create_new_scaffolds {
    my ($self, $old_contigs, $scaffolds) = @_;

    my $new_scafs = {};
    #hash of scaffolds with array of contigs in scaffold as value
    #$new_scafs->{scaffold?}->{scaffold_contigs} = [
    #                                               contig??
    #                                               contig??
    #                                              ]

    my $scaf_lengths = {};
    #hash of scaffold name and scaffold size
    #$scaf_lengths->{'contig'} = length_of_scaffold

    if ($scaffolds) {
	foreach my $scaf (@$scaffolds) {

	    $scaf =~ s/\s+//;

	    if ($scaf =~ /-/) {
		my @tmp = split (/-/, $scaf);
		my $scaf_ctg_1;
		foreach my $scaf_ctg (@tmp) {
		    next if $scaf_ctg eq 'E'; #eg E-12.1-E

		    #scaffold name is the first contig in scaffold
		    $scaf_ctg_1 = $scaf_ctg unless $scaf_ctg_1;
		    if ($scaf_ctg =~ /c/) {#eg 12.1c signifies that ctg may need to be complemented 
			#print ("\nConsed thinks the following contig should be flipped: $scaf_ctg\nContinue? (yes/no) ");


			#TODO - make it so that it just complements the contig rather than doing this

			$self->status_message("\nConsed thinks the following contig should be flipped: $scaf_ctg\nContinue? (yes/no) ");
			chomp (my $answer = <STDIN>);
			if ($answer eq 'no') {
			    #print "Exiting ..\n";
			    #exit (0);
			    $self->status_message("Exiting");
			    return;
			}

			$scaf_ctg =~ s/c//;
		    }

		    #print "$scaf_ctg is not in correct contig name format\n" and exit (1)
			#unless ($scaf_ctg =~ /^\d+$/ or $scaf_ctg =~ /^\d+\.\d+$/);
		    
		    unless ($scaf_ctg =~ /^\d+$/ or $scaf_ctg =~ /^\d+\.\d+$/) {
			$self->error_message("$scaf_ctg is not in correct contig name format\n");
			return;
		    }


		    push @{$new_scafs->{$scaf_ctg_1}->{scaffold_contigs}}, $scaf_ctg;
		    $scaf_lengths->{$scaf_ctg_1} += $old_contigs->{$scaf_ctg};
		}
	    }
	    else {
#		print "$scaf is not in correct contig name format\n" and exit (1)
#		    unless ($scaf =~ /^\d+$/ or $scaf =~ /^\d+\.\d+$/);
		unless ($scaf =~ /^\d+$/ or $scaf =~ /^\d+\.\d+$/) {
		    $self->error_message("$scaf is not in correct contig name format");
		    return;
		}


		push @{$new_scafs->{$scaf}->{scaffold_contigs}}, $scaf;
		$scaf_lengths->{$scaf} += $old_contigs->{$scaf};
	    }
	}
    }
    else {
	foreach my $contig (keys %$old_contigs) {
	    push @{$new_scafs->{$contig}->{scaffold_contigs}}, $contig;
	    $scaf_lengths->{$contig} = $old_contigs->{$contig};
	}
    }

    #new scaffold numbers start with 0; new contig numbers start with 1
    #Contig0.1 is first scaffold, first contig

    my $new_scaf_num = 0;
    my $new_ctg_num = 1;
    my $new_scaf_names = {};

    #write a new gap file
    my $gap_file = $self->assembly_directory.'/edit_dir/msi.gap.txt';
    my $gap_fh = IO::File->new("> $gap_file") || die "Can not write new gap file: msi.gap.txt";

    foreach my $scaf (sort {$scaf_lengths->{$b} <=> $scaf_lengths->{$a}} keys %{$scaf_lengths}) {
	if (scalar @{$new_scafs->{$scaf}->{scaffold_contigs}} > 1) {
	    foreach my $scaf_ctg ( @{$new_scafs->{$scaf}->{scaffold_contigs}} ) {
		my $new_ctg_name = 'Contig'.$new_scaf_num.'.'.$new_ctg_num;
		$new_scaf_names->{$scaf_ctg} = $new_ctg_name;
		$new_ctg_num++;

		$gap_fh->print("$new_ctg_name 100\n");
	    }
	    $new_ctg_num = 1;
	}
	else {
	    my $scaf_ctg = @{$new_scafs->{$scaf}->{scaffold_contigs}}[0];
	    my $new_ctg_name = 'Contig'.$new_scaf_num.'.'.$new_ctg_num;
	    $new_scaf_names->{$scaf} = $new_ctg_name;
	}

	$new_scaf_num++;
    }

    $gap_fh->close;

    return $new_scaf_names;
}

sub _write_new_ace_file {
    my ($self, $ace, $scaffold) = @_;
    my $ace_out = $self->assembly_directory.'/edit_dir/new.msi.ace';
    my $fh_out = IO::File->new("> $ace_out") ||
	die "Can not create file handle to write new ace\n";
    my $fh_in = IO::File->new("< $ace") ||
	die "Can not create file handle to read $ace\n";
    my $in_contig_tag = 0;
    while (my $line = $fh_in->getline) {
	#CHANGE CONTIG NAMES IN CO LINE
	if ($line =~ /^CO\s+/) {
	    chomp $line;
	    my ($contig_name) = $line =~ /^CO\s+(\S+)/;
	    my $rest_of_line = "$'";
	    my ($contig_number) = $contig_name =~ /contig(\S+)/i;
	    if (exists $scaffold->{$contig_number}) {
		$fh_out->print('CO '.$scaffold->{$contig_number}." $rest_of_line\n");
	    }
	    else {
		if ($contig_number =~ /^\d+$/) {
		    $fh_out->print('CO Contig'.$contig_number.'.1'." $rest_of_line\n");
		}
		else {
		    $fh_out->print("$line\n");
		}
	    }
	}
	#CHANGE CONTIG NAMES IN CONTIG TAGS
	elsif ($line =~ /^CT\{/) {
	    $in_contig_tag = 1;
	    $fh_out->print($line);
	}
	elsif ($in_contig_tag == 1 and $line =~ /^contig(\S+)\s+/i) {
	    chomp $line;
	    my ($contig_name) = $line =~ /^(\S+)/;
	    my $rest_of_line = "$'";
	    my ($contig_number) = $contig_name =~ /contig(\S+)/i;
	    if (exists $scaffold->{$contig_number}) {
		$fh_out->print($scaffold->{$contig_number}."$rest_of_line\n");
	    }
	    else{
		$fh_out->print("$line\n");
	    }
	    $in_contig_tag = 0;
	}
	else {
	    $fh_out->print($line);
	}
    }
    $fh_in->close;
    $fh_out->close;
    #return 'new.msi.ace';
    return $self->assembly_directory.'/edit_dir/new.msi.ace';
}

sub _update_ds_line {#and write wa_tag
    my ($self, $ace) = @_;
    my $fh = IO::File->new("< $ace") || die "can not open file: $ace";

    my $ace_out = $self->assembly_directory.'/edit_dir/ace.msi';

    my $out_fh = IO::File->new("> $ace_out") || die "Can not write file: new.msi.ace.final";
    while (my $line = $fh->getline) {
	if ($line =~ /^DS\s+/) {
	    if ($line =~ /PHD_FILE/) {
		$out_fh->print($line);
	    }
	    else {
		$line =~ s/DS /DS VERSION: 1 /;
		$out_fh->print($line);
	    }
	}
	else {
	    $out_fh->print($line);
	}
    }
    $fh->close;

#    my $ball_dir = '../phdball_dir';
    my $ball_dir = $self->assembly_directory.'/phdball_dir';
    if (-d $ball_dir) {
	my @phd_ball_file = glob ("$ball_dir/*ball");
	if (scalar @phd_ball_file > 0) {
	    foreach (@phd_ball_file) {
		$out_fh->print("\nWA{\n"."phdBall newbler 080416:144002\n".$_."\n}\n\n");
	    }
	}
    }

    $out_fh->close;
    #return 'ace.msi';
    return 1;
}

1
