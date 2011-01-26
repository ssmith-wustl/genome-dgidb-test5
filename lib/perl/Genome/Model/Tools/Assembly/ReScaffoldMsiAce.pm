package Genome::Model::Tools::Assembly::ReScaffoldMsiAce;

use strict;
use warnings;

use Genome;
use Data::Dumper;

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
gmt assembly re-scaffold-msi-ace --acefile /gscmnt/111/assembly/edit_dir/newbler.ace --assembly-directory /gscmnt/111/assembly
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

    #TODO - needs some clean up

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
	print $report_file."\n";
    }

    if ($self->scaffold_file) {
	unless (-s $self->scaffold_file) {
	    $self->error_message("Can't find scaffold file: ".$self->scaffold_file);
	    return;
	}
	$report_file = $self->scaffold_file;
    }

    #parse report file .. returns aryref .. could be empty if no scaffolds
    my $old_scaffolds = $self->_get_old_scaffolds($self->acefile);
    my $new_scaffolds;

    if ($report_file) {
	my $scaffolds = $self->_parse_report_file($report_file);
	my $valid_scaffolds = $self->_check_for_contigs_to_complement($scaffolds);
	$new_scaffolds = $self->_create_new_scaffolds($old_scaffolds, $valid_scaffolds);
    }
    else {
	$new_scaffolds = $self->_create_new_scaffolds($old_scaffolds);
    }
    my $new_ace = $self->_write_new_ace_file($self->acefile, $new_scaffolds);

    my $final_ace = $self->_update_ds_line($new_ace);

    #TODO - this update ds line is not needed anymore
    unlink $new_ace;

    return 1;
}

sub _run_auto_report {
    my $self = shift;
    $self->status_message("Running consed auto report");
    #TODO - this doesn't seem to work any more .. not sure, no clear errs
    #my $run = GSC::IO::Scaffold::Consed::Run->new($self->acefile);
    #unless ($run->execute) {#TODO - make sure this has correct exit code
	#$self->error_message("Failed to run consed auto report");
	#return;
    #}
    my $acefile = $self->acefile;
    if (system("consed -ace $acefile -autoreport")) {
	$self->error_message("Failed to run consed auto report on ace file: $acefile");
	return;
    }
    my $dir = $self->assembly_directory.'/edit_dir';
    my @out_files = `ls -t $dir/*[0-9]\.out`; #grap autoreport output files
    unless (@out_files) {
	$self->error_message("Failed to find any auto report output files with file format ####.out");
	return;
    }
    chomp @out_files;

    return shift @out_files;
}

sub _parse_report_file {
    my ($self, $file) = @_;
    my @scaffolds;
    my $fh = Genome::Sys->open_file_for_reading($file) ||
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

sub _check_for_contigs_to_complement {
    my ($self, $scaffolds) = @_;
    my $contigs_to_complement;
    foreach (@$scaffolds) {
	my @tmp = split ('-', $_);
	foreach (@tmp) {
	    $contigs_to_complement .= $_.', ' if $_ =~ /c/;
	}
    }
    if ($contigs_to_complement) {
	if ($self->auto_report) {
	    $self->status_message("\n\nConsed autoreport suggests that the following contigs must be complemented:\n".
				  "\t$contigs_to_complement .. please complement these contigs in the ace file and run the program again\nExiting");
	}
	if ($self->scaffold_file) {
	    $self->status_message("\nPlease complement the following contigs in the ace file: $contigs_to_complement\n".
				  "Then remove c from contig numbers then run the program again to reflect correct compelementation in post assembly files");
	}
	return;
    }
    return $scaffolds;
}

sub _get_old_scaffolds {
    my ($self, $ace) = @_;

    my $contig_lengths = {};
    my $fh = IO::File->new("<$ace") || die "Can not open ace file: $ace";
    while (my $line = $fh->getline) {
	next unless $line =~ /^CO\s+/;
	my ($contig_name, $length) = $line =~ /^CO\s+(\S+)\s+(\d+)/;
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
    #TODO - needs some clean up
    my $new_scafs = {};
    #hash of scaffolds with array of contigs in scaffold as value
    #$new_scafs->{scaffold?}->{scaffold_contigs} = [
    #                                               contig??
    #                                               contig??
    #                                              ]
    my $scaf_lengths = {};
    #hash of scaffold name and scaffold size
    if ($scaffolds) {
	foreach my $scaf (@$scaffolds) {
	    $scaf =~ s/\s+//;
	    #TODO - don't differentiate between scaf with - and w/o .. no need
	    my @tmp = split (/-/, $scaf);
	    my $scaf_ctg_1;
	    foreach my $scaf_ctg (@tmp) {
		next if $scaf_ctg eq 'E'; #eg E-12.1-E
		$scaf_ctg_1 = $scaf_ctg unless $scaf_ctg_1;
		push @{$new_scafs->{$scaf_ctg_1}->{scaffold_contigs}}, $scaf_ctg;
		$scaf_lengths->{$scaf_ctg_1} += $old_contigs->{$scaf_ctg};
		delete $old_contigs->{$scaf_ctg};
	    }
	}
    }
	   
    #rename the remaining, non-scaffold contigs
    foreach my $contig (keys %$old_contigs) {
	push @{$new_scafs->{$contig}->{scaffold_contigs}}, $contig;
	$scaf_lengths->{$contig} = $old_contigs->{$contig};
	delete $old_contigs->{$contig};
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
	foreach my $scaf_ctg ( @{$new_scafs->{$scaf}->{scaffold_contigs}} ) {
	    my $new_ctg_name = 'Contig'.$new_scaf_num.'.'.$new_ctg_num;
	    $new_scaf_names->{$scaf_ctg} = $new_ctg_name;
	    #print gap info to gap file only if part of multi contigs scaffold
	    if (scalar @{$new_scafs->{$scaf}->{scaffold_contigs}} > 1) {
		#dont' print gap size if last contig in scaffold
		next if $new_ctg_num == scalar @{$new_scafs->{$scaf}->{scaffold_contigs}};
		$gap_fh->print("$new_ctg_name 100\n");
	    }
	    $new_ctg_num++; #increment for next contig
	}
	$new_ctg_num = 1; #reset for next scaffold
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

    return 1;
}

1
