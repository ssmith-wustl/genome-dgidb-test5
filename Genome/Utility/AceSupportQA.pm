package Genome::Utility::AceSupportQA;

use strict;
use warnings;
use Benchmark;
use DBI;

use above 'Genome';


###MODIFIED so that it doesn't fix anything
my $fix_invalid_files;
my ($traces_fof,$trace_files_needed,$phd_files_needed,$poly_files_needed);
sub ace_support_qa {

    my $t0 = new Benchmark;

    #my ($ace_file,$fix_invalid_files) = @_; ##Give full path to ace file including ace file name
    my ($ace_file) = @_; ##Give full path to ace file including ace file name

    my $usage = "Give full path to ace file including ace file name";
    unless (@ARGV == 1) {die "$usage\n";}
#    chomp ($ace_file);


    my ($no_ace) = &check_for_file($ace_file); #will only return if there is no file or an empty file

    if ($no_ace) { 
	my $check;
	if ($ace_file) {
	    $check = "$ace_file is $no_ace";
	} else {
	    $check = "No ace file provided";
	}
	return $check;
    }
    #invalid_files will be a has of trace names and file type that are broken.
    my ($invalid_files,$project) = &parse_ace_file($ace_file); ##QA the read dump, phred and poly files
	
    my $run;
    if ($invalid_files) {

	$run = qq(There are invalid files for $project that should be fixed prior to analysis\n);

	print qq(Here is a list of reads for $project with either a broken chromat, phd, or poly file\n);
	foreach my $read (sort keys %{$invalid_files}) {
	    print qq($read);
	    foreach my $file_type (sort keys %{$invalid_files->{$read}}) {
		print qq(\t$file_type);
	    }
	    print qq(\n);
	}
    } else {
	$run = qq(OK to start analysis on $project\n);
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
	    
	    if ($fix_invalid_files) {system qq(read_dump -scf-gz $read --output-dir=$chromat_dir);}
	    
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

    my $invalid_files;

    unless ($read_count) { die "There are no reads in the ace file to be analyzed\n"; }

    print qq(Reads for analysis ==> $read_count\n);

    
    if ($no_trace_file || $empty_trace_file) {

	unless($no_trace_file) {$no_trace_file=0;}
	unless($empty_trace_file) {$empty_trace_file=0;}

	my $n = $no_trace_file + $empty_trace_file;
	print qq(nonviable trace files ==> $n\n);
	foreach my $read (sort keys %{$trace_files_needed}) {
	    if ($fix_invalid_files) {print qq(attempted redump of $read failed\n);}
	    $invalid_files->{$read}->{trace}=1;
	}
    }
    
    if ($no_poly_file || $empty_poly_file) {
	if ($no_poly_file eq $read_count) {
	    print qq(There are no poly files, they can be created in analysis\n);
	} else {

	    unless($no_poly_file) {$no_poly_file=0;}
	    unless($empty_poly_file) {$empty_poly_file=0;}

	    my $n = $no_poly_file + $empty_poly_file;
	    if ($fix_invalid_files) {print qq(will run phred to produce $n disfunctional poly files\n);}
	    foreach my $read (sort keys %{$poly_files_needed}) {
		if ($trace_files_needed->{$read}) {
		    if ($fix_invalid_files) {
			print qq(no attempt made to produce a poly file for $read as the trace file is missing\n);
		    }
		    $invalid_files->{$read}->{poly}=1;
		} else {
		    if ($fix_invalid_files) {system qq(phred -dd $poly_dir $chromat_dir/$read.gz);}
		    my $poly = "$poly_dir/$read.poly";
		    ($poly) = &check_for_file($poly);
		    if ($poly) { 
			if ($fix_invalid_files) {print qq(attempted to produce a poly file for $read failed\n);}
			$invalid_files->{$read}->{poly}=1;
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
	
	unless($no_phd_file) {$no_phd_file=0;}
	unless($empty_phd_file) {$empty_phd_file=0;}
	
	my $n = $no_phd_file + $empty_phd_file;
	
	if ($fix_invalid_files) {print qq(will run phred to produce $n disfunctional phd files\n);}
	foreach my $read (sort keys %{$phd_files_needed}) {
	    if ($trace_files_needed->{$read}) {
		if ($fix_invalid_files) {
		    print qq(no attempt made to produce a phd file for $read as the trace file is missing\n);
		}
		$invalid_files->{$read}->{phd}=1;
	    } else {
		#if ($fix_invalid_files) {system qq(phred -pd $phd_dir $chromat_dir/$read.gz);}
		my $phd = "$phd_dir/$read.phd.1";
		($phd) = &check_for_file($phd);
		if ($phd) { 
		    #print qq(attempted to produce a phd file for $read failed\n);
		    $invalid_files->{$read}->{phd}=1;
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
	if ($fix_invalid_files) {
	    print qq(will attempt to sync the phd file time stamps with the ace file\n);
	    #system qq(/gscmnt/200/medseq/biodb/shared/TCGA_GBM/rmeyer/TEST/scripts/fix_autojoin_DS_line.pl $ace_file);
	    
	    ($ace_file)=&sync_phd_time_stamps($ace_file);
	    my ($no_ace) = &check_for_file($ace_file);
	    
	    if ($no_ace) { 
		die "The synced ace file $ace_file is $no_ace";
		#my $check = "The synced ace file $ace_file is $no_ace";
		#$invalid_files++;
		#return $check;
	    }
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
