package Genome::Utility::AceSupportQA;

use strict;
use warnings;
use Benchmark;
use DBI;

use above 'Genome';


my ($traces_fof,$trace_files_needed,$phd_files_needed,$poly_files_needed);
sub ace_support_qa {

    my $t0 = new Benchmark;
    
    my ($ace_file) = @_; ##Give full path to ace file including ace file name
    chomp ($ace_file);
    my ($no_ace) = &check_for_file($ace_file);

    if ($no_ace) { 
	my $check = "$ace_file is $no_ace";
	return $check;
    }
    
    my ($invalid_files,$project) = &parse_ace_file($ace_file); ##QA the read dump, phred and poly files
	
    my $run;
    if ($invalid_files) {
	if ($invalid_files == 1) {
	    $run = qq(go ahead and try to run analysis for $project however, it will most likely fail, there was $invalid_files invalid file\n);

	    #$run = "NOT_OK";
	} else {
	    $run = qq(go ahead and try to run analysis for $project however, it will most likely fail, there were $invalid_files invalid files\n);
	    #$run = "NOT_OK";

	}
    } else {
	$run = qq(OK to start analysis on $project\n);
	#$run = "OK";
	
    }
    
    my $t1 = new Benchmark;
    my $td = timediff($t1, $t0);
    print "the code took:",timestr($td),"\n";
    
    if ($run) {
	return ($run);
    }

}


sub check_for_file { #will only return no_file or empty
    my ($file) = @_;
    unless ($file && -e $file) {
	$file = "no_file";
	return $file;
    }
    $file = &check_for_empty_file($file);
    if ($file) {
	return $file;
    }
}

sub check_for_empty_file {
    my ($file) = @_;
    my $ll = `ls -l $file`;
    my ($n) = (split(/\s/,$ll))[4];

    if ($n < 1) {
	return ("empty");
    }
}

sub parse_ace_file {

    my ($ace_file) = @_;
    
    my @da = split(/\//,$ace_file);
    my $ace_name = pop(@da);
    
    my $edit_dir = join'/',@da;
    
    pop(@da);
    my $project_dir = join'/',@da;
    my $project = pop(@da);
    
    my $chromat_dir = "$project_dir/chromat_dir";
    my $phd_dir = "$project_dir/phd_dir";
    my $poly_dir = "$project_dir/poly_dir";
    
    use GSC::IO::Assembly::Ace;
    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace_file);

    my $contig_count;
    foreach my $name (@{ $ao->get_contig_names }) {
	$contig_count++;
	my $contig = $ao->get_contig($name);
	foreach my $read_name (keys %{ $contig->reads }) {
	    unless ($read_name =~ /(\S+\.c1)$/) {
		$traces_fof->{$read_name}=1;
	    }
	}
    }

    unless ($contig_count == 1) {print qq($project Contig count is equal to $contig_count\n);}
    my ($invalid_files)=&check_traces_fof($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file);
    return ($invalid_files,$project);
}

sub check_traces_fof {
    my ($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file) = @_;
    
    my ($no_trace_file,$no_phd_file,$no_poly_file,$empty_trace_file,$empty_poly_file,$empty_phd_file,$ncntrl_reads,$read_count,$repaired_file);
    
    foreach my $read (sort keys %{$traces_fof}) {
	$read_count++;
	
	if ($read =~ /^n\-cntrl/) {$ncntrl_reads++;}
	
	my $trace = "$chromat_dir/$read.gz";
	my ($dump_trace) = &check_for_file($trace);
	if ($dump_trace) {
	    system qq(read_dump -scf-gz $read --output-dir=$chromat_dir);
	    ($trace) = &check_for_file($trace);
	    if ($trace eq "no_file") { 
		$no_trace_file++;
		$trace_files_needed->{$read}=1;
	    } elsif ($trace eq "empty") {
		$empty_trace_file++;
		$trace_files_needed->{$read}=1;
	    } else {
		$repaired_file++;
	    }
	}
	
	my $poly = "$poly_dir/$read.poly";
	($poly) = &check_for_file($poly);
	if ($poly eq "no_file") { 
	    $no_poly_file++;
	    $poly_files_needed->{$read}=1;
	} elsif ($poly eq "empty") {
	    $empty_poly_file++;
	    $poly_files_needed->{$read}=1;
	}
	
	my $phd = "$phd_dir/$read.phd.1";
	($phd) = &check_for_file($phd);
	if ($phd eq "no_file") { 
	    $no_phd_file++;
	    $phd_files_needed->{$read}=1;
	} elsif ($phd eq "empty") {
	    $empty_phd_file++;
	    $phd_files_needed->{$read}=1;
	}
    }
    print qq(Reads for analysis ==> $read_count\n);

    my $invalid_files;
    
    if ($no_trace_file || $empty_trace_file) {
	my $n = $no_trace_file + $empty_trace_file;
	print qq(nonviable trace files ==> $n\n);
	foreach my $read (sort keys %{$trace_files_needed}) {
	    print qq(attempted redump of $read failed\n);
	    $invalid_files++;
	}
    }
    
    if ($no_poly_file || $empty_poly_file) {
	if ($no_poly_file eq $read_count) {
	    print qq(There are no poly files, they can be created in analysis\n);
	} else {
	    my $n = $no_poly_file + $empty_poly_file;
	    print qq(will run phred to produce $n disfunctional poly files\n);
	    foreach my $read (sort keys %{$poly_files_needed}) {
		if ($trace_files_needed->{$read}) {
		    print qq(no attempt made to produce a poly file for $read as the trace file is missing\n);
		    $invalid_files++;
		} else {
		    system qq(phred -dd $poly_dir $chromat_dir/$read.gz);
		    my $poly = "$poly_dir/$read.poly";
		    ($poly) = &check_for_file($poly);
		    if ($poly) { 
			print qq(attempted to produce a poly file for $read failed\n);
			$invalid_files++;
		    } else {
			$repaired_file++;
			print qq(poly file for $read ok\n);
		    }
		}
	    }
	}
    }

    my ($check_phd_time_stamps);    
    if ($no_phd_file || $empty_phd_file) {
	my $n = $no_phd_file + $empty_phd_file;
	print qq(will run phred to produce $n disfunctional phd files\n);
	foreach my $read (sort keys %{$phd_files_needed}) {
	    if ($trace_files_needed->{$read}) {
		print qq(no attempt made to produce a phd file for $read as the trace file is missing\n);
		$invalid_files++;
	    } else {
		#system qq(phred -pd $phd_dir $chromat_dir/$read.gz);
		my $phd = "$phd_dir/$read.phd.1";
		($phd) = &check_for_file($phd);
		if ($phd) { 
		    #print qq(attempted to produce a phd file for $read failed\n);
		    $invalid_files++;
		} else {
		    $repaired_file++;
		    #$check_phd_time_stamps=1;
		    #print qq(phd file for $read ok\n);
		}
	    }
	}
    }


    ##sync_phd_time_stamps is not working correctly. It didn't change the time stamp in the ace file
    if ($check_phd_time_stamps) {
	print qq(will attempt to sync the phd file time stamps with the ace file\n);
	#system qq(/gscmnt/200/medseq/biodb/shared/TCGA_GBM/rmeyer/TEST/scripts/fix_autojoin_DS_line.pl $ace_file);

	($ace_file)=&sync_phd_time_stamps($ace_file);
	my ($no_ace) = &check_for_file($ace_file);
	
	if ($no_ace) { 
	    my $check = "The synced ace file $ace_file is $no_ace";
	    $invalid_files++;
	    return $check;
	}
    }
    
    if ($ncntrl_reads) {
	print OUT qq(There were $ncntrl_reads n-cntrl reads\n);
    }
    
    return ($invalid_files);
}


sub sync_phd_time_stamps {

    #addapted from ~kkyung/bin/fix_autojoin_DS_line.pl

    use IO::File;
    use Data::Dumper;
    
    my ($ace) = @_;
    system qq(cp $ace $ace.presync);
    open(NEWACE,">$ace.synced");

    my $fh = IO::File->new("<$ace") || die "Can not open $ace";
    
    my $ds = {};
    
    while (my $line = $fh->getline)
    {
	if ($line =~ /^DS\s/)
	{
	    my ($version) = $line =~ /VERSION:\s+(\d+)/;
	    my ($chromat) = $line =~ /CHROMAT_FILE:\s+(\S+)/;
	    my ($phd_file) = $line =~ /PHD_FILE:\s+(\S+)/;
	    my ($time) = $line =~ /TIME:\s+(\w+\s+\w+\s+\d+\s+\d+\:\d+\:\d+\s+\d+)/;
	    my ($chem) = $line =~ /CHEM:\s+(\S+)/;
	    my ($dye) = $line =~ /DYE:\s+(\S+)/;
	    my ($template) = $line =~ /TEMPLATE:\s+(\S+)/;
	    my ($direction) = $line =~ /DIRECTION:\s+(\S+)/;
	    
	    $ds->{chromat_file} = (defined $chromat) ? $chromat : 'unknown';
	    $ds->{version} = (defined $version) ? $version : 'unknown';
	    $ds->{phd_file} = (defined $phd_file) ? $phd_file : 'unknown';
	    $ds->{time} = (defined $time) ? $time : 'unknown';
	    $ds->{chem} = (defined $chem) ? $chem : 'unknown';
	    $ds->{dye} = (defined $dye) ? $dye : 'unknown';
	    $ds->{template} = (defined $template) ? $template : 'unknown';
	    $ds->{direction} = (defined $direction) ? $direction : 'unknown';
	    $ds->{is_454} = ($chromat =~ /\.sff\:/) ? 'yes' : 'no';
	    
	    #error unless defined ds->{chromat_file};
	    #error unless defined ds->{time};
	    #print Dumper $ds;
	    
	    my $ds_line = 'DS ';
	    if ($chromat =~ /\.sff\:/)
	    {
		$ds_line .= 'VERSION: '.$ds->{version}.' ' unless $ds->{version} eq 'unknown';
	    }
	    $ds_line .= 'CHROMAT_FILE: '.$ds->{chromat_file}.' ';
	    $ds_line .= 'PHD_FILE: '.$ds->{phd_file}.' ' unless $ds->{phd_file} eq 'unknown';
	    $ds_line .= 'TIME: '.$ds->{time}.' ';
	    $ds_line .= 'CHEM: '.$ds->{chem}.' ' unless $ds->{chem} eq 'unknown';
	    $ds_line .= 'DYE: '.$ds->{dye}.' ' unless $ds->{dye} eq 'unknown';
	    $ds_line .= 'TEMPLATE: '.$ds->{template}.' ' unless $ds->{template} eq 'unknown';
	    $ds_line .= 'DIRECTION: '.$ds->{direction}.' ' unless $ds->{direction} eq 'unknown';
	    
	    $ds_line =~ s/\s+$//;
	    
	    print NEWACE $ds_line."\n";
	    
	}
	else
	{
	    print NEWACE $line;
	}
    }
    $fh->close;
    close(NEWACE);

    system qq(cp $ace.synced $ace);
    return($ace);
}

1;
